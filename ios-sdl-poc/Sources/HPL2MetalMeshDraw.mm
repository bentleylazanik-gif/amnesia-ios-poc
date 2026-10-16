#import "HPL2MetalMeshDraw.h"

#import <simd/simd.h>

#include <cstring>
#include <stdint.h>

NSErrorDomain const HPL2MetalMeshDrawErrorDomain =
    @"org.example.amnesia.HPL2MetalMeshDraw";

@interface HPL2MetalMeshDraw ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property (nonatomic, strong) MTLVertexDescriptor *vertexDescriptor;
@property (nonatomic) NSUInteger vertexBufferCount;
@end

namespace {

void SetDrawError(NSError **error, HPL2MetalMeshDrawErrorCode code,
                  NSString *description, NSError *underlyingError = nil)
{
    if (error != NULL) {
        NSMutableDictionary *info =
            [NSMutableDictionary dictionaryWithObject:description
                                               forKey:NSLocalizedDescriptionKey];
        if (underlyingError != nil) {
            info[NSUnderlyingErrorKey] = underlyingError;
        }
        *error = [NSError errorWithDomain:HPL2MetalMeshDrawErrorDomain
                                    code:code
                                userInfo:info];
    }
}

NSUInteger AttributeIndex(hpl::eVertexBufferElement semantic)
{
    switch (semantic) {
    case hpl::eVertexBufferElement_Position: return 0;
    case hpl::eVertexBufferElement_Color0: return 2;
    case hpl::eVertexBufferElement_Texture0: return 3;
    default: return NSNotFound;
    }
}

BOOL VertexDescriptorsMatch(MTLVertexDescriptor *left,
                            MTLVertexDescriptor *right)
{
    for (NSUInteger index = 0; index < 5; ++index) {
        MTLVertexAttributeDescriptor *leftAttribute = left.attributes[index];
        MTLVertexAttributeDescriptor *rightAttribute = right.attributes[index];
        if (leftAttribute.format != rightAttribute.format ||
            leftAttribute.offset != rightAttribute.offset ||
            leftAttribute.bufferIndex != rightAttribute.bufferIndex) {
            return NO;
        }
        MTLVertexBufferLayoutDescriptor *leftLayout = left.layouts[index];
        MTLVertexBufferLayoutDescriptor *rightLayout = right.layouts[index];
        if (leftLayout.stride != rightLayout.stride ||
            leftLayout.stepFunction != rightLayout.stepFunction ||
            leftLayout.stepRate != rightLayout.stepRate) {
            return NO;
        }
    }
    return YES;
}

BOOL HasRequiredAttribute(HPL2MetalMeshUpload *upload,
                          hpl::eVertexBufferElement semantic)
{
    const NSUInteger wantedIndex = AttributeIndex(semantic);
    if (wantedIndex == NSNotFound) {
        return NO;
    }
    MTLVertexAttributeDescriptor *attribute =
        upload.vertexDescriptor.attributes[wantedIndex];
    return attribute.format != MTLVertexFormatInvalid;
    return NO;
}

static const char kHPL2UnlitShaderSource[] =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "struct VertexIn {\n"
    "  float4 position [[attribute(0)]];\n"
    "  float4 color [[attribute(2)]];\n"
    "  float3 uv [[attribute(3)]];\n"
    "};\n"
    "struct VertexUniforms { float4x4 projection; float4x4 modelView; };\n"
    "struct VertexOut { float4 position [[position]]; float4 color; float2 uv; };\n"
    "vertex VertexOut hpl2UnlitVertex(VertexIn in [[stage_in]],\n"
    "  constant VertexUniforms &u [[buffer(5)]]) {\n"
    "  VertexOut out;\n"
    "  out.position = u.projection * u.modelView * in.position;\n"
    "  out.color = in.color;\n"
    "  out.uv = in.uv.xy;\n"
    "  return out;\n"
    "}\n"
    "fragment float4 hpl2UnlitFragment(VertexOut in [[stage_in]],\n"
    "  texture2d<float> diffuse [[texture(0)]], sampler diffuseSampler [[sampler(0)]],\n"
    "  constant uint &useDiffuse [[buffer(0)]]) {\n"
    "  float4 texel = useDiffuse != 0 ? diffuse.sample(diffuseSampler, in.uv) : float4(1.0);\n"
    "  return in.color * texel;\n"
    "}\n";

struct HPL2MetalDrawUniforms
{
    simd_float4x4 projection;
    simd_float4x4 modelView;
};

} // namespace

@implementation HPL2MetalMeshDraw

+ (nullable instancetype)drawPathWithDevice:(id<MTLDevice>)device
                                 meshUpload:(HPL2MetalMeshUpload *)meshUpload
                                colorFormat:(MTLPixelFormat)colorFormat
                                      error:(NSError * _Nullable * _Nullable)error
{
    if (error != NULL) {
        *error = nil;
    }
    if (device == nil || meshUpload == nil || colorFormat == MTLPixelFormatInvalid ||
        !HasRequiredAttribute(meshUpload, hpl::eVertexBufferElement_Position) ||
        !HasRequiredAttribute(meshUpload, hpl::eVertexBufferElement_Color0) ||
        !HasRequiredAttribute(meshUpload, hpl::eVertexBufferElement_Texture0)) {
        SetDrawError(error, HPL2MetalMeshDrawErrorInvalidArgument,
                     @"The Metal device, color format, or required HPL2 attributes are missing.");
        return nil;
    }

    NSString *shaderSource =
        [NSString stringWithUTF8String:kHPL2UnlitShaderSource];
    NSError *metalError = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:shaderSource
                                                  options:nil
                                                    error:&metalError];
    if (library == nil) {
        SetDrawError(error, HPL2MetalMeshDrawErrorShaderCompilation,
                     @"Could not compile the inline unlit Metal test/backend shader.",
                     metalError);
        return nil;
    }
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"hpl2UnlitVertex"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"hpl2UnlitFragment"];
    if (vertexFunction == nil || fragmentFunction == nil) {
        SetDrawError(error, HPL2MetalMeshDrawErrorShaderCompilation,
                     @"The HPL2 unlit Metal shader entry points are missing.");
        return nil;
    }

    MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.label = @"HPL2 simple unlit indexed pass";
    descriptor.vertexFunction = vertexFunction;
    descriptor.fragmentFunction = fragmentFunction;
    descriptor.vertexDescriptor = meshUpload.vertexDescriptor;
    descriptor.colorAttachments[0].pixelFormat = colorFormat;
    id<MTLRenderPipelineState> pipeline =
        [device newRenderPipelineStateWithDescriptor:descriptor error:&metalError];
    if (pipeline == nil) {
        SetDrawError(error, HPL2MetalMeshDrawErrorPipelineCreation,
                     @"Could not create the HPL2-format unlit Metal pipeline.", metalError);
        return nil;
    }

    HPL2MetalMeshDraw *draw = [[self alloc] init];
    draw.device = device;
    draw.pipeline = pipeline;
    draw.vertexDescriptor = meshUpload.vertexDescriptor;
    draw.vertexBufferCount = meshUpload.vertexBuffers.count;
    return draw;
}

- (BOOL)encodeMesh:(HPL2MetalMeshUpload *)meshUpload
           encoder:(id<MTLRenderCommandEncoder>)encoder
        projection:(const HPL2MetalMatrix4x4 *)projection
         modelView:(const HPL2MetalMatrix4x4 *)modelView
     diffuseTexture:(id<MTLTexture>)diffuseTexture
             sampler:(id<MTLSamplerState>)sampler
          useDiffuse:(BOOL)useDiffuse
               error:(NSError * _Nullable * _Nullable)error
{
    if (error != NULL) {
        *error = nil;
    }
    if (meshUpload == nil || encoder == nil || projection == NULL || modelView == NULL ||
        diffuseTexture == nil || sampler == nil ||
        meshUpload.vertexBuffers.count == 0 || meshUpload.indexBuffer == nil ||
        meshUpload.drawIndexCount == 0 || meshUpload.drawIndexCount > meshUpload.indexCount) {
        SetDrawError(error, HPL2MetalMeshDrawErrorInvalidArgument,
                     @"The mesh, encoder, matrices, texture, sampler, or indexed draw count is invalid.");
        return NO;
    }
    if (meshUpload.vertexBuffers.count != self.vertexBufferCount ||
        !VertexDescriptorsMatch(meshUpload.vertexDescriptor, self.vertexDescriptor)) {
        SetDrawError(error, HPL2MetalMeshDrawErrorInvalidArgument,
                     @"The uploaded mesh vertex layout differs from the pipeline layout.");
        return NO;
    }
    if (meshUpload.indexBuffer.device != self.device ||
        diffuseTexture.device != self.device) {
        SetDrawError(error, HPL2MetalMeshDrawErrorInvalidArgument,
                     @"The mesh buffers, texture, and draw pipeline must use the same Metal device.");
        return NO;
    }
    for (id<MTLBuffer> buffer in meshUpload.vertexBuffers) {
        if (buffer.device != self.device) {
            SetDrawError(error, HPL2MetalMeshDrawErrorInvalidArgument,
                         @"A vertex buffer belongs to a different Metal device.");
            return NO;
        }
    }

    HPL2MetalDrawUniforms uniforms;
    memcpy(&uniforms.projection, projection->values, sizeof(uniforms.projection));
    memcpy(&uniforms.modelView, modelView->values, sizeof(uniforms.modelView));
    const uint32_t useDiffuseValue = useDiffuse ? 1u : 0u;

    [encoder setRenderPipelineState:self.pipeline];
    for (NSUInteger index = 0; index < meshUpload.vertexBuffers.count; ++index) {
        [encoder setVertexBuffer:meshUpload.vertexBuffers[index]
                          offset:0
                         atIndex:index];
    }
    [encoder setVertexBytes:&uniforms
                     length:sizeof(uniforms)
                    atIndex:5];
    [encoder setFragmentTexture:diffuseTexture atIndex:0];
    [encoder setFragmentSamplerState:sampler atIndex:0];
    [encoder setFragmentBytes:&useDiffuseValue
                       length:sizeof(useDiffuseValue)
                      atIndex:0];
    [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:meshUpload.drawIndexCount
                         indexType:MTLIndexTypeUInt32
                       indexBuffer:meshUpload.indexBuffer
                 indexBufferOffset:0];
    return YES;
}

@end
