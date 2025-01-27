#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct 
{

    uint8_t BootJumpInstruction[3]; // 3 bytes

    uint8_t OEMIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptor;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // extended boot record
    
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeID;              // Volume serial number, value doesn't matter
    uint8_t VolumeLabel[11];        // 11byte, padded with spaces
    uint8_t SystemId[8];
} __attribute__((packed)) BootSector;

typedef struct {
    
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreationTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;

} __attribute__((packed)) DirectoryEntry;



BootSector g_BootSector;
uint8_t* g_fat;
DirectoryEntry* g_rootDir = NULL;
uint32_t g_rootDirEnd;

bool readBootSector(FILE* disk) {
    return fread(&g_BootSector, sizeof(BootSector), 1, disk) > 0;
}

bool readSectors(FILE* disk, uint32_t sector, uint32_t count, void* buffer) {
    bool ok = true;
    ok = ok && (fseek(disk, sector * g_BootSector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(buffer, g_BootSector.BytesPerSector, count, disk) == count);
    return ok;
}

bool readFat(FILE* disk) {
    g_fat = (uint8_t*) malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_fat);
}

bool readRootDirectory(FILE* disk) {
    uint32_t lba = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount; 
    uint32_t size = sizeof(DirectoryEntry) * g_BootSector.DirEntryCount;
    uint32_t sectors = (size / g_BootSector.BytesPerSector);
    if(size % g_BootSector.BytesPerSector > 0)
        sectors++;

    g_rootDirEnd = lba + sectors;
    g_rootDir = (DirectoryEntry*) malloc(sectors * g_BootSector.BytesPerSector);
    return readSectors(disk, lba, sectors, g_rootDir);

}

DirectoryEntry* findFile(const char* name) {
    for (uint32_t i = 0; i < g_BootSector.DirEntryCount; i++) {
        if (memcmp(name, g_rootDir[i].Name, 11) == 0)
            return &g_rootDir[i];
    }

    return NULL;
}

bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer){

    bool ok = true;
    uint16_t currentCluster = fileEntry->FirstClusterLow;

    do {
        uint32_t lba = g_rootDirEnd + (currentCluster - 2) * g_BootSector.SectorsPerCluster;
        ok = ok && readSectors(disk, lba, g_BootSector.SectorsPerCluster, outputBuffer);
        outputBuffer += g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector;

        uint32_t fatIndex = currentCluster * 3 / 2;
        if (currentCluster % 2 == 0) {
            currentCluster = (*(uint16_t*)(g_fat + fatIndex)) & 0x0FFF;
        } else {
            currentCluster = (*(uint16_t*)(g_fat + fatIndex)) >> 4;
        }

    } while (ok && currentCluster < 0xFF8);
    return ok;
}


int main(int argc, char** argv){
    if(argc < 3) {
        printf("Usage: %s <disk img> <filename>\n", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");
    if(!disk) {
        fprintf(stderr, "Failed to open disk image %s!!!\n", argv[1]);
        return -1;
    }

    if(!readBootSector(disk)) {
        fprintf(stderr, "Failed to read boot sector!!!\n");
        return -2;
    }

    if(!readFat(disk)) {
        fprintf(stderr, "Failed to read FAT!!!\n");
        free(g_fat);
        return -3;
    }

    if(!readRootDirectory(disk)) {
        fprintf(stderr, "Failed to read root directory!!!\n");
        free(g_fat);
        free(g_rootDir);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);
    if(!fileEntry) {
        fprintf(stderr, "File %s not found!!!\n", argv[2]);
        free(g_fat);
        free(g_rootDir);
        return -5;
    }

    uint8_t* buffer = (uint8_t*) malloc(fileEntry->Size + g_BootSector.BytesPerSector);
    if(!readFile(fileEntry, disk, buffer)) {
        fprintf(stderr, "Failed to read file %s!!!\n", argv[2]);
        free(g_fat);
        free(g_rootDir);
        free(buffer);
        return -6;
    }
    
    for (size_t i = 0; i < fileEntry->Size; i++) {
        
        if(isprint(buffer[i])) fputc(buffer[i], stdout);
        else printf("\\x%02x", buffer[i]);
        
    }
    printf("\n");

    free(g_fat);
    free(g_rootDir);
    return 0;
}