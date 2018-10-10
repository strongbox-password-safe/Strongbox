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

@interface ODPhoto()
{
    NSDate *_takenDateTime;
}
@end

@implementation ODPhoto	

- (NSString *)cameraMake
{
    return self.dictionary[@"cameraMake"];
}

- (void)setCameraMake:(NSString *)cameraMake
{
    self.dictionary[@"cameraMake"] = cameraMake;
}

- (NSString *)cameraModel
{
    return self.dictionary[@"cameraModel"];
}

- (void)setCameraModel:(NSString *)cameraModel
{
    self.dictionary[@"cameraModel"] = cameraModel;
}


- (CGFloat)exposureDenominator
{
    
    if (self.dictionary[@"exposureDenominator"]){
        return [self.dictionary[@"exposureDenominator"] floatValue];
    }
    //default value if it doesn't exists
    return [@(0) floatValue];
}

- (void)setExposureDenominator:(CGFloat)exposureDenominator
{
    self.dictionary[@"exposureDenominator"] = @(exposureDenominator);
}


- (CGFloat)exposureNumerator
{
    
    if (self.dictionary[@"exposureNumerator"]){
        return [self.dictionary[@"exposureNumerator"] floatValue];
    }
    //default value if it doesn't exists
    return [@(0) floatValue];
}

- (void)setExposureNumerator:(CGFloat)exposureNumerator
{
    self.dictionary[@"exposureNumerator"] = @(exposureNumerator);
}


- (CGFloat)focalLength
{
    
    if (self.dictionary[@"focalLength"]){
        return [self.dictionary[@"focalLength"] floatValue];
    }
    //default value if it doesn't exists
    return [@(0) floatValue];
}

- (void)setFocalLength:(CGFloat)focalLength
{
    self.dictionary[@"focalLength"] = @(focalLength);
}


- (CGFloat)fNumber
{
    
    if (self.dictionary[@"fNumber"]){
        return [self.dictionary[@"fNumber"] floatValue];
    }
    //default value if it doesn't exists
    return [@(0) floatValue];
}

- (void)setFNumber:(CGFloat)fNumber
{
    self.dictionary[@"fNumber"] = @(fNumber);
}

- (NSDate *)takenDateTime
{
    if(!_takenDateTime){
        _takenDateTime = [self dateFromString:self.dictionary[@"takenDateTime"]];
    }
    return _takenDateTime;
}

- (void)setTakenDateTime:(NSDate *)takenDateTime
{
    _takenDateTime = takenDateTime;
    self.dictionary[@"takenDateTime"] = takenDateTime; 
}


- (int32_t)iso
{
    
    if (self.dictionary[@"iso"]){
        return [self.dictionary[@"iso"] intValue];
    }
    //default value if it doesn't exists
    return [@(0) intValue];
}

- (void)setIso:(int32_t)iso
{
    self.dictionary[@"iso"] = @(iso);
}

@end
