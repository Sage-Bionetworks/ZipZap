//
//  ZZFileChannel.m
//  ZipZap
//
//  Created by Glen Low on 12/01/13.
//  Copyright (c) 2013, Pixelglow Software. All rights reserved.
//

#import "ZZError.h"
#import "ZZFileChannel.h"
#import "ZZFileChannelOutput.h"

@implementation ZZFileChannel
{
	NSURL* _URL;
}

- (instancetype)initWithURL:(NSURL*)URL
{
	if ((self = [super init]))
		_URL = URL;
	return self;
}

- (NSURL*)URL
{
	return _URL;
}

- (instancetype)temporaryChannel:(out NSError**)error
{
	NSURL* temporaryDirectory = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
																	   inDomain:NSUserDomainMask
															  appropriateForURL:_URL
																		 create:NO
																		  error:error];
	
	// Make sure (if we can) that the temporary directory has the same file protection class as the reference URL
	NSDictionary *tdAttrs = [NSFileManager.defaultManager attributesOfItemAtPath:temporaryDirectory.path error:nil];
	NSFileProtectionType tdProtection = tdAttrs[NSFileProtectionKey];
	
	NSURL *refUrl = _URL;
	NSFileProtectionType refProtection = nil;
	while (!refProtection && refUrl.pathComponents.count) {
		NSDictionary *refAttrs = [NSFileManager.defaultManager attributesOfItemAtPath:refUrl.path error:nil];
		refProtection = refAttrs[NSFileProtectionKey];
		refUrl = [refUrl URLByDeletingLastPathComponent];
	}
	if (refProtection && ![tdProtection isEqualToString:refProtection]) {
		[NSFileManager.defaultManager setAttributes:@{ NSFileProtectionKey : refProtection } ofItemAtPath:temporaryDirectory.path error:nil];
	}
	
	return temporaryDirectory ? [[ZZFileChannel alloc] initWithURL:[temporaryDirectory URLByAppendingPathComponent:_URL.lastPathComponent]] : nil;
}

- (BOOL)replaceWithChannel:(id<ZZChannel>)channel
					 error:(out NSError**)error
{
	NSURL* __autoreleasing resultingURL;
	return [[NSFileManager defaultManager] replaceItemAtURL:_URL
											  withItemAtURL:channel.URL
											 backupItemName:nil
													options:0
										   resultingItemURL:&resultingURL
													  error:error];
}

- (void)removeAsTemporary
{
	[[NSFileManager defaultManager] removeItemAtURL:[_URL URLByDeletingLastPathComponent]
											  error:nil];
}

- (NSData*)newInput:(out NSError**)error
{
	return [[NSData alloc] initWithContentsOfURL:_URL
										 options:NSDataReadingMappedAlways
										   error:error];
}

- (id<ZZChannelOutput>)newOutput:(out NSError**)error
{
	int fileDescriptor =  open(_URL.path.fileSystemRepresentation,
							   O_WRONLY | O_CREAT,
							   S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
	if (fileDescriptor == -1)
	{
		if (error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain
										 code:errno
									 userInfo:nil];
		return nil;
	}
	else
		return [[ZZFileChannelOutput alloc] initWithFileDescriptor:fileDescriptor];
}

@end
