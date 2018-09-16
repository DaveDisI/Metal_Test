#include <Cocoa/Cocoa.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>

typedef struct
{
    // Positions in pixel space
    // (e.g. a value of 100 indicates 100 pixels from the center)
    vector_float2 position;

    // Floating-point RGBA colors
    vector_float4 color;
} AAPLVertex;

NSString *shaders = @"\
#include <metal_stdlib>\n\
using namespace metal;\n\
\
vertex float4 vertexShader(uint vertexID [[vertex_id]], constant float2 *vertices){\n\
    return float4(vertices[vertexID], 0, 1);\n\
}\n\
\
fragment float4 fragmentShader(){\n\
    return float4(0, 1, 1, 1);\n\
}\
";

int main(int argc, char** argv){
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApp sharedApplication];
    NSUInteger windowStyle = NSWindowStyleMaskTitled        | 
                             NSWindowStyleMaskClosable      | 
                             NSWindowStyleMaskResizable     | 
                             NSWindowStyleMaskMiniaturizable;

	NSRect screenRect = [[NSScreen mainScreen] frame];
	NSRect viewRect = NSMakeRect(0, 0, 500, 500); 
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
    id<MTLRenderPipelineState> pipelineState;
    id<MTLCommandQueue> commandQueue;
    unsigned int width, height;
    MTKView * view = [[MTKView alloc] initWithFrame: viewRect
                                             device: device];
    view.paused = true;
    //view.enableSetNeedsDisplay = true;
    if(view){
        device = view.device;
        NSError* err;
        // Load all the shader files with a .metal file extension in the project
        //id<MTLLibrary> defaultLibrary = [device newLibraryWithFile:@"shaders.metallib" 
        //                                                     error:&err];
        MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
        id<MTLLibrary> defaultLibrary = [device newLibraryWithSource:shaders
                                                             options: options 
                                                             error:&err];

        // Load the vertex function from the library
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        
        // Load the fragment function from the library
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

        // Configure a pipeline descriptor that is used to create a pipeline state
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;

        pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&err];
        if (!pipelineState)
        {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created pipeline state, error %@", err);
            return 1;
        }

		commandQueue = [device newCommandQueue];
    }
    float triangleVertices[] = {
            -1, -1,
            0, 1,
            1, -1,
    };

    id<MTLBuffer> vertBuffer = [device newBufferWithBytes: triangleVertices
                                        length: sizeof(triangleVertices)
                                        options: MTLResourceStorageModeShared];

    width = view.bounds.size.width;
    height = view.bounds.size.height;
    
    [window setContentView:view];
    [window setTitle:[[NSProcessInfo processInfo] processName]];
    [window setAcceptsMouseMovedEvents:YES];
    [window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];
	[window orderFrontRegardless];  

    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];

    NSEvent* ev;  
    while(true){
        do {
            ev = [NSApp nextEventMatchingMask: NSEventMaskAny
                                    untilDate: nil
                                       inMode: NSDefaultRunLoopMode
                                      dequeue: YES];
            if (ev) {
                if([ev type] == NSEventTypeKeyDown){
                   switch([ev keyCode]){
                       case 53:{
                           [NSApp terminate:NSApp];
                           break;
                       }
                       case 0:{
                           NSLog(@"A\n");
                           break;
                       }
                   }
                }else{
                    [NSApp sendEvent: ev];
                }
            }
        } while (ev);

        //view.clearColor = MTLClearColorMake(0, 1, 1, 1);

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

            // Set the region of the drawable to which we'll draw.
            [renderEncoder setViewport:(MTLViewport){0.0, 0.0, width, height, -1.0, 1.0 }];
            [renderEncoder setRenderPipelineState:pipelineState];

            [renderEncoder setVertexBuffer:vertBuffer
                                offset:0
                               atIndex:0];

            // Draw the 3 vertices of our triangle
            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                            vertexStart:0
                            vertexCount:3];

            // Since we aren't drawing anything, indicate we're finished using this encoder
            [renderEncoder endEncoding];

            // Add a final command to present the cleared drawable to the screen
            [commandBuffer presentDrawable:view.currentDrawable];
        }

        // Finalize rendering here and submit the command buffer to the GPU
        [commandBuffer commit];
    }

    [pool release];
}