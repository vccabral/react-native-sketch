//
//  RNSketch.m
//  RNSketch
//
//  Created by Jeremy Grancher on 28/04/2016.
//  Copyright © 2016 Jeremy Grancher. All rights reserved.
//

#import <React/RCTEventDispatcher.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>
#import "RNSketch.h"
#import "RNSketchManager.h"

@implementation RNSketch
{
    // Internal
    RCTEventDispatcher *_eventDispatcher;
    UIButton *_clearButton;
    UIBezierPath *_path;
    NSArray *bezierPointsArray; //added as global variable to track all points
    UIImage *_image;
    CGPoint _points[5];
    uint _counter;
    
    // Configuration settings
    UIColor *_fillColor;
    UIColor *_strokeColor;
}


#pragma mark - UIViewHierarchy methods


- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    if ((self = [super init])) {
        // Internal setup
        self.multipleTouchEnabled = NO;
        // For borderRadius property to work (CALayer's cornerRadius).
        self.layer.masksToBounds = YES;
        _eventDispatcher = eventDispatcher;
        _path = [UIBezierPath bezierPath];
        
        [self initClearButton];
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self drawBitmap];
}

- (void)setClearButtonHidden:(BOOL)hidden
{
    _clearButton.hidden = hidden;
}


#pragma mark - Subviews


- (void)initClearButton
{
    // Clear button
    CGRect frame = CGRectMake(0, 0, 40, 40);
    _clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _clearButton.frame = frame;
    _clearButton.enabled = false;
    _clearButton.tintColor = [UIColor blackColor];
    _clearButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [_clearButton setTitle:@"x" forState:UIControlStateNormal];
    [_clearButton addTarget:self action:@selector(clearDrawing) forControlEvents:UIControlEventTouchUpInside];
    
    // Clear button background
    UIButton *background = [UIButton buttonWithType:UIButtonTypeCustom];
    background.frame = frame;
    
    // Add subviews
    [self addSubview:background];
    // [self addSubview:_clearButton];
}


#pragma mark - UIResponder methods


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    _counter = 0;
    UITouch *touch = [touches anyObject];
    _points[0] = [touch locationInView:self];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    _counter++;
    UITouch *touch = [touches anyObject];
    _points[_counter] = [touch locationInView:self];
    
    if (_counter == 4) [self drawCurve];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // Enabling to clear
    [_clearButton setEnabled:true];
    
    [self drawBitmap];
    [self setNeedsDisplay];
    //get all points before removing the path
    bezierPointsArray = [self getAllPoints];
    
    [_path removeAllPoints];
    _counter = 0;
    
    // Send event
    NSDictionary *bodyEvent = @{
                                @"target": self.reactTag,
                                @"image": [self drawingToString],
                                };
    [_eventDispatcher sendInputEventWithName:@"topChange" body:bodyEvent];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}


#pragma mark - UIViewRendering methods


- (void)drawRect:(CGRect)rect
{
    [_image drawInRect:rect];
    [_strokeColor setStroke];
    [_path stroke];
}


#pragma mark - Drawing methods


- (void)drawCurve
{
    // Move the endpoint to the middle of the line
    _points[3] = CGPointMake((_points[2].x + _points[4].x) / 2, (_points[2].y + _points[4].y) / 2);
    
    [_path moveToPoint:_points[0]];
    [_path addCurveToPoint:_points[3] controlPoint1:_points[1] controlPoint2:_points[2]];
    
    [self setNeedsDisplay];
    
    // Replace points and get ready to handle the next segment
    _points[0] = _points[3];
    _points[1] = _points[4];
    _counter = 1;
}

- (void)drawBitmap
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
    
    // If first time, paint background
    if (!_image) {
        [_fillColor setFill];
        [[UIBezierPath bezierPathWithRect:self.bounds] fill];
    }
    
    // Draw with context
    [_image drawAtPoint:CGPointZero];
    [_strokeColor setStroke];
    [_path stroke];
    _image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
}


- (NSMutableArray *) getAllPoints
{
    //_path
    NSMutableArray *points = [NSMutableArray array];
    CGPathApply(_path.CGPath, (__bridge void *)points, getPointsFromBezier);
    
    return points;
}

- (NSArray * ) getBezierPointsArray{
    return bezierPointsArray;
}

void getPointsFromBezier (void *info, const CGPathElement *element)
{
    NSMutableArray *bezierPoints = (__bridge NSMutableArray *)info;
    
    CGPoint *points = element->points;
    CGPathElementType type = element->type;
    NSMutableDictionary *pointsDictionary = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *points2Dictionary = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *points3Dictionary = [[NSMutableDictionary alloc] init];
    switch(type) {
        case kCGPathElementMoveToPoint:
        case kCGPathElementAddLineToPoint: 
                [pointsDictionary setValue:[[NSNumber alloc] initWithFloat:points[0].x] forKey:@"x"];
                [pointsDictionary setValue:[[NSNumber alloc] initWithFloat:points[0].y] forKey:@"y"];
                [bezierPoints addObject:pointsDictionary];
            break;
            
        case kCGPathElementAddQuadCurveToPoint: // contains 2 points
              [pointsDictionary setValue:[[NSNumber alloc] initWithFloat:points[0].x] forKey:@"x"];
              [pointsDictionary setValue:[[NSNumber alloc] initWithFloat:points[0].y] forKey:@"y"];
              [bezierPoints addObject:pointsDictionary];
              [pointsDictionary2 setValue:[[NSNumber alloc] initWithFloat:points[1].x] forKey:@"x"];
              [pointsDictionary2 setValue:[[NSNumber alloc] initWithFloat:points[1].y] forKey:@"y"];
              [bezierPoints addObject:pointsDictionary2];
            break;
            
        case kCGPathElementAddCurveToPoint: // contains 3 points
              [pointsDictionary setValue:[[NSNumber alloc] initWithFloat:points[0].x] forKey:@"x"];
              [pointsDictionary setValue:[[NSNumber alloc] initWithFloat:points[0].y] forKey:@"y"];
              [bezierPoints addObject:pointsDictionary];
              [pointsDictionary2 setValue:[[NSNumber alloc] initWithFloat:points[1].x] forKey:@"x"];
              [pointsDictionary2 setValue:[[NSNumber alloc] initWithFloat:points[1].y] forKey:@"y"];
              [bezierPoints addObject:pointsDictionary2];
              [pointsDictionary2 setValue:[[NSNumber alloc] initWithFloat:points[2].x] forKey:@"x"];
              [pointsDictionary2 setValue:[[NSNumber alloc] initWithFloat:points[2].y] forKey:@"y"];
              [bezierPoints addObject:pointsDictionary3];
            break;
            
        case kCGPathElementCloseSubpath: // contains no point
            break;
    }
}

#pragma mark - Export drawing


- (NSString *)drawingToString
{
    return [UIImagePNGRepresentation(_image) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}


#pragma mark - Clear drawing


- (void)clearDrawing
{
    // Disabling to clear
    [_clearButton setEnabled:false];
    
    _image = nil;
    
    [self drawBitmap];
    [self setNeedsDisplay];
    
    // Send event
    NSDictionary *bodyEvent = @{
                                @"target": self.reactTag,
                                };
    [_eventDispatcher sendInputEventWithName:@"onReset" body:bodyEvent];
}


- (int)score
{
    return 0;
}

#pragma mark - Setters


- (void)setFillColor:(UIColor *)fillColor
{
    _fillColor = fillColor;
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    _strokeColor = strokeColor;
}

- (void)setStrokeThickness:(NSInteger)strokeThickness
{
    _path.lineWidth = strokeThickness;
}

@end
