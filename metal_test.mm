#include <Cocoa/Cocoa.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>

@class WindowDelegate;
@interface WindowDelegate : NSView <NSWindowDelegate> {
@public
	NSRect windowRect;
}   
@end

@implementation WindowDelegate
-(void)windowWillClose:(NSNotification *)notification {
	[NSApp terminate:self];
}
@end

@class WindowView;
@interface WindowView : NSObject <MTKViewDelegate> {
@public
	NSRect windowRect;
}   
@end

@implementation WindowView{
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
}
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self){
        device = mtkView.device;
		commandQueue = [device newCommandQueue];
    }
    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{

}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view{
    view.clearColor = MTLClearColorMake(0, 1, 1, 1);
    
    // Create a new command buffer for each render pass to the current drawable
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a render pass descriptor, generated from the view's drawable
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    // If you've successfully obtained a render pass descriptor, you can render to
    // the drawable; otherwise you skip any rendering this frame because you have no
    // drawable to draw to
    if(renderPassDescriptor != nil)
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

        renderEncoder.label = @"MyRenderEncoder";

        // We would normally use the render command encoder to draw our objects, but for
        //   the purposes of this sample, all we need is the GPU clear command that
        //   Metal implicitly performs when we create the encoder.

        // Since we aren't drawing anything, indicate we're finished using this encoder
        [renderEncoder endEncoding];

        // Add a final command to present the cleared drawable to the screen
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here and submit the command buffer to the GPU
    [commandBuffer commit];
}

@end

int main(int argc, char** argv){
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];

    NSUInteger windowStyle = NSWindowStyleMaskTitled        | 
                             NSWindowStyleMaskClosable      | 
                             NSWindowStyleMaskResizable     | 
                             NSWindowStyleMaskMiniaturizable;

	NSRect screenRect = [[NSScreen mainScreen] frame];
	NSRect viewRect = NSMakeRect(0, 0, 800, 600); 
	NSRect windowRect = NSMakeRect(NSMidX(screenRect) - NSMidX(viewRect),
								 NSMidY(screenRect) - NSMidY(viewRect),
								 viewRect.size.width, 
								 viewRect.size.height);

	NSWindow * window = [[NSWindow alloc] initWithContentRect:windowRect 
						styleMask:windowStyle 
						backing:NSBackingStoreBuffered 
						defer:NO]; 
	[window autorelease]; 
 
	NSWindowController * windowController = [[NSWindowController alloc] initWithWindow:window]; 
	[windowController autorelease]; 

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    MTKView * view = [[MTKView alloc] initWithFrame: viewRect
                                             device: device];
    WindowView* metalView = [WindowView alloc];
    [metalView initWithMetalKitView: view];
    [view setDelegate:metalView];

    [window setContentView:view];
    WindowDelegate *delegate = [WindowDelegate alloc];
    [delegate autorelease];
    [window setDelegate:delegate];
    [window setTitle:[[NSProcessInfo processInfo] processName]];
    [window setAcceptsMouseMovedEvents:YES];
    [window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];
	[window orderFrontRegardless];  

    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
    [pool release];
    return 0;
}