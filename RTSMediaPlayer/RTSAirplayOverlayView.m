//
//  Copyright (c) SRG. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RTSAirplayOverlayView.h"
#import "NSBundle+RTSMediaPlayer.h"

@interface RTSAirplayOverlayView () <RTSAirplayOverlayViewDataSource>
@property (nonatomic, strong) MPVolumeView *volumeView;
@end

static const CGFloat RTSAirplayOverlayViewDefaultFillFactor = 0.6f;

@implementation RTSAirplayOverlayView

- (id)initWithFrame:(CGRect)frame
{
	if(!(self = [super initWithFrame:frame]))
		return nil;
	
	self.autoresizesSubviews = YES;
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	self.backgroundColor = [UIColor clearColor];
	
	[self setupView];
	
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if(!(self = [super initWithCoder:aDecoder]))
		return nil;
	
	[self setupView];
	
	return self;
}

- (void)setupView
{
	self.contentMode = UIViewContentModeRedraw;
	self.userInteractionEnabled = NO;
	self.hidden = YES;
    self.fillFactor = RTSAirplayOverlayViewDefaultFillFactor;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(wirelessRouteActiveDidChange:)
												 name:MPVolumeViewWirelessRouteActiveDidChangeNotification
											   object:nil];
	
	self.volumeView = [[MPVolumeView alloc] init];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)activeAirplayOutputRouteName
{
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	AVAudioSessionRouteDescription *currentRoute = audioSession.currentRoute;
	
	for (AVAudioSessionPortDescription *outputPort in currentRoute.outputs) {
		if ([outputPort.portType isEqualToString:AVAudioSessionPortAirPlay]) {
			return outputPort.portName;
		}
	}
	
	return RTSMediaPlayerLocalizedString(@"External device", nil);
}

- (void)setFillFactor:(CGFloat)fillFactor
{
    if (fillFactor <= 0.f) {
        _fillFactor = RTSAirplayOverlayViewDefaultFillFactor;
    }
    else if (fillFactor > 1.f) {
        _fillFactor = 1.f;
    }
    else {
        _fillFactor = fillFactor;
    }
    
    [self setNeedsDisplay];
}


#pragma mark - Notifications

- (void)wirelessRouteActiveDidChange:(NSNotification *)notification
{
	[self setNeedsDisplay];
	
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	AVAudioSessionRouteDescription *currentRoute = audioSession.currentRoute;
	
	BOOL hidden = YES;
	for (AVAudioSessionPortDescription *outputPort in currentRoute.outputs) {
		if ([outputPort.portType isEqualToString:AVAudioSessionPortAirPlay]) {
            hidden = NO;
            if (self.delegate && [self.delegate respondsToSelector:@selector(airplayOverlayViewCouldBeDisplayed:)]) {
                if (![self.delegate airplayOverlayViewCouldBeDisplayed:self]) {
                    hidden = YES;
                }
            }

			break;
		}
	}
	
	[self setHidden:hidden];
}



#pragma mark - Drawings

- (void)drawRect:(CGRect)rect
{
	CGFloat width, height;
	CGFloat stringRectHeight = 30.0;
	CGFloat stringRectMargin = 5.0;
	CGFloat lineWidth = 4.0;
	CGFloat shapeSeparatorDelta = 5.0f;
	CGFloat quadCurveHeight = 20.0f;
	
	CGFloat maxWidth = CGRectGetWidth(self.bounds) * self.fillFactor - 2*lineWidth;
	CGFloat maxHeight = CGRectGetHeight(self.bounds) * self.fillFactor - stringRectHeight - quadCurveHeight - shapeSeparatorDelta - 10.;
	CGFloat aspectRatio = 16./10.0;
	
	if (maxWidth < maxHeight * aspectRatio) {
		width = maxWidth;
		height = width / aspectRatio;
	}
	else {
		height = maxHeight;
		width = height * aspectRatio;
	}
	
	CGFloat midX = CGRectGetMidX(rect);
	CGFloat midY = CGRectGetMidY(rect);
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetAllowsAntialiasing(context, YES);
	
	CGContextSetLineWidth(context, 4.0);
	CGContextSetStrokeColorWithColor(context, self.tintColor.CGColor);
	
	CGRect rectangle = CGRectMake(midX-width/2.0, midY-height/2.0, width, height);
	CGContextAddRect(context, rectangle);
	CGContextStrokePath(context);
	
	CGContextMoveToPoint(context, midX-width/4.0, midY+height/2.0+shapeSeparatorDelta);
	CGContextAddQuadCurveToPoint(context, midX, midY+height/2.0+quadCurveHeight, midX+width/4.0, midY+height/2.0+shapeSeparatorDelta);
	CGContextSetFillColorWithColor(context, self.tintColor.CGColor);
	CGContextFillPath(context);
	
	CGRect titleRect = CGRectInset(rectangle, 8.0, 10.0);
	[self drawTitleInRect:titleRect];
	
	CGRect subtitleRect = CGRectMake(stringRectMargin, midY+height/2.0+quadCurveHeight-5.0, CGRectGetMaxX(rect)-2*stringRectMargin, stringRectHeight);
	[self drawSubtitleInRect:subtitleRect];
}

- (void)drawTitleInRect:(CGRect)rect
{
	NSDictionary *attributes = [self airplayOverlayViewTitleAttributedDictionary:self];
	if ([self.dataSource respondsToSelector:@selector(airplayOverlayViewTitleAttributedDictionary:)]) {
		attributes = [self.dataSource airplayOverlayViewTitleAttributedDictionary:self];
	}
	
	NSStringDrawingContext *drawingContext = [[NSStringDrawingContext alloc] init];
	
	NSString *title = @"Airplay";
	[title drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:drawingContext];
}

- (void)drawSubtitleInRect:(CGRect)rect
{
	NSString *routeName = [self activeAirplayOutputRouteName];
	
	NSString *subtitle = [self airplayOverlayView:self subtitleForAirplayRouteName:routeName];
	if ([self.dataSource respondsToSelector:@selector(airplayOverlayView:subtitleForAirplayRouteName:)]) {
		subtitle = [self.dataSource airplayOverlayView:self subtitleForAirplayRouteName:routeName];
	}
	
	if (subtitle.length > 0) {
		NSDictionary* attributes = [self airplayOverlayViewSubitleAttributedDictionary:self];
		if ([self.dataSource respondsToSelector:@selector(airplayOverlayViewSubitleAttributedDictionary:)]) {
			attributes = [self.dataSource airplayOverlayViewSubitleAttributedDictionary:self];
		}
		
		NSStringDrawingContext *drawingContext = [[NSStringDrawingContext alloc] init];
		drawingContext.minimumScaleFactor = 3/4;
		
		[subtitle drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:drawingContext];
	}
}



#pragma mark - RTSAirplayOverlayViewDataSource

- (NSDictionary *)airplayOverlayViewTitleAttributedDictionary:(RTSAirplayOverlayView *)airplayOverlayView
{
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	style.alignment = NSTextAlignmentCenter;
	
	return @{ NSFontAttributeName : [UIFont boldSystemFontOfSize:14.0f],
			  NSForegroundColorAttributeName : self.tintColor,
			  NSParagraphStyleAttributeName: style };
}

- (NSString *)airplayOverlayView:(RTSAirplayOverlayView *)airplayOverlayView subtitleForAirplayRouteName:(NSString *)routeName
{
	return [NSString stringWithFormat:RTSMediaPlayerLocalizedString(@"This media is playing on «%@»", nil), routeName];
}

- (NSDictionary *)airplayOverlayViewSubitleAttributedDictionary:(RTSAirplayOverlayView *)airplayOverlayView
{
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	style.alignment = NSTextAlignmentCenter;
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	
	return @{ NSFontAttributeName : [UIFont systemFontOfSize:12.0f],
			  NSForegroundColorAttributeName : self.tintColor,
			  NSParagraphStyleAttributeName: style };
}

@end
