// Copyright (c) 2015 Microsoft Corporation
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
// 
// CodeGen: b53160c326682c5d0326144548f8f1a5297b0f62


//////////////////////////////////////////////////////////////////
// This file was generated and any changes will be overwritten. //
//////////////////////////////////////////////////////////////////



#import "ODModels.h"

@interface ODObject()

@property (strong, nonatomic) NSMutableDictionary *dictionary;

@end

@interface ODAudio()
{
}
@end

@implementation ODAudio	

- (NSString *)album
{
    return self.dictionary[@"album"];
}

- (void)setAlbum:(NSString *)album
{
    self.dictionary[@"album"] = album;
}

- (NSString *)albumArtist
{
    return self.dictionary[@"albumArtist"];
}

- (void)setAlbumArtist:(NSString *)albumArtist
{
    self.dictionary[@"albumArtist"] = albumArtist;
}

- (NSString *)artist
{
    return self.dictionary[@"artist"];
}

- (void)setArtist:(NSString *)artist
{
    self.dictionary[@"artist"] = artist;
}


- (int64_t)bitrate
{
    
    if (self.dictionary[@"bitrate"]){
        return [self.dictionary[@"bitrate"] longLongValue];
    }
    //default value if it doesn't exists
    return [@(0) longLongValue];
}

- (void)setBitrate:(int64_t)bitrate
{
    self.dictionary[@"bitrate"] = @(bitrate);
}

- (NSString *)composers
{
    return self.dictionary[@"composers"];
}

- (void)setComposers:(NSString *)composers
{
    self.dictionary[@"composers"] = composers;
}

- (NSString *)copyright
{
    return self.dictionary[@"copyright"];
}

- (void)setCopyright:(NSString *)copyright
{
    self.dictionary[@"copyright"] = copyright;
}


- (int16_t)disc
{
    
    if (self.dictionary[@"disc"]){
        return [self.dictionary[@"disc"] intValue];
    }
    //default value if it doesn't exists
    return [@(0) intValue];
}

- (void)setDisc:(int16_t)disc
{
    self.dictionary[@"disc"] = @(disc);
}


- (int16_t)discCount
{
    
    if (self.dictionary[@"discCount"]){
        return [self.dictionary[@"discCount"] intValue];
    }
    //default value if it doesn't exists
    return [@(0) intValue];
}

- (void)setDiscCount:(int16_t)discCount
{
    self.dictionary[@"discCount"] = @(discCount);
}


- (int64_t)duration
{
    
    if (self.dictionary[@"duration"]){
        return [self.dictionary[@"duration"] longLongValue];
    }
    //default value if it doesn't exists
    return [@(0) longLongValue];
}

- (void)setDuration:(int64_t)duration
{
    self.dictionary[@"duration"] = @(duration);
}

- (NSString *)genre
{
    return self.dictionary[@"genre"];
}

- (void)setGenre:(NSString *)genre
{
    self.dictionary[@"genre"] = genre;
}


- (BOOL)hasDrm
{
    
    if (self.dictionary[@"hasDrm"]){
        return [self.dictionary[@"hasDrm"] boolValue];
    }
    //default value if it doesn't exists
    return [@(0) boolValue];
}

- (void)setHasDrm:(BOOL)hasDrm
{
    self.dictionary[@"hasDrm"] = @(hasDrm);
}


- (BOOL)isVariableBitrate
{
    
    if (self.dictionary[@"isVariableBitrate"]){
        return [self.dictionary[@"isVariableBitrate"] boolValue];
    }
    //default value if it doesn't exists
    return [@(0) boolValue];
}

- (void)setIsVariableBitrate:(BOOL)isVariableBitrate
{
    self.dictionary[@"isVariableBitrate"] = @(isVariableBitrate);
}

- (NSString *)title
{
    return self.dictionary[@"title"];
}

- (void)setTitle:(NSString *)title
{
    self.dictionary[@"title"] = title;
}


- (int32_t)track
{
    
    if (self.dictionary[@"track"]){
        return [self.dictionary[@"track"] intValue];
    }
    //default value if it doesn't exists
    return [@(0) intValue];
}

- (void)setTrack:(int32_t)track
{
    self.dictionary[@"track"] = @(track);
}


- (int32_t)trackCount
{
    
    if (self.dictionary[@"trackCount"]){
        return [self.dictionary[@"trackCount"] intValue];
    }
    //default value if it doesn't exists
    return [@(0) intValue];
}

- (void)setTrackCount:(int32_t)trackCount
{
    self.dictionary[@"trackCount"] = @(trackCount);
}


- (int32_t)year
{
    
    if (self.dictionary[@"year"]){
        return [self.dictionary[@"year"] intValue];
    }
    //default value if it doesn't exists
    return [@(0) intValue];
}

- (void)setYear:(int32_t)year
{
    self.dictionary[@"year"] = @(year);
}

@end
