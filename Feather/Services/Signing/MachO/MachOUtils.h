@import Darwin;
@import Foundation;
@import MachO;

NSString *LCPatchMachOFixupARM64eSlice(const char *path);
NSString *LCPatchMachOForSDK26(const char *path);
NSData *LCGetMachOEntitlements(const char *path);
