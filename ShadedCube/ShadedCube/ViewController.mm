//
//  ViewController.m
//  ShadedCube - shading calculations done in-app (quad function), not shaders.
//
//  Created by Marc Mauger on 5/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#include "Angel.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))


// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};

typedef GLKVector3 vec3;
typedef GLKVector4 vec4;
typedef GLKVector4 point4;
typedef GLKVector4 color4;
typedef GLKMatrix4 mat4;

const int NumVertices = 36;

int axis = 0;
float theta[3] = {0.0, 0.0, 0.0};
float aspect;

// Vertices of a unit cube centered at origin, sides aligned with axes
point4  vertices[8] = {GLKVector4Make(-0.5,-0.5,0.5, 1.0),
    GLKVector4Make(-0.5,0.5,0.5, 1.0),
    GLKVector4Make(0.5,0.5,0.5, 1.0), 
    GLKVector4Make(0.5,-0.5,0.5, 1.0), 
    GLKVector4Make(-0.5,-0.5,-0.5, 1.0),
    GLKVector4Make(-0.5,0.5,-0.5, 1.0), 
    GLKVector4Make(0.5,0.5,-0.5, 1.0), 
    GLKVector4Make(0.5,-0.5,-0.5, 1.0)};

vec4 viewer = GLKVector4Make(0.0, 0.0, 1.0, 0.0);
point4 light_position = GLKVector4Make(0.0, 0.0, -1.0, 0.0);
color4 light_ambient = GLKVector4Make(0.2, 0.2, 0.2, 1.0);
color4 light_diffuse = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
color4 light_specular = GLKVector4Make(1.0, 1.0, 1.0, 1.0);

color4 material_ambient = GLKVector4Make(1.0, 0.0, 1.0, 1.0);
color4 material_diffuse = GLKVector4Make(1.0, 0.8, 0.0, 1.0);
color4 material_specular = GLKVector4Make(1.0, 0.8, 0.0, 1.0);
float material_shininess = 100.0;

point4 points[NumVertices];
color4 quad_color[NumVertices];
mat4 ctm;

void quad(int a, int b, int c, int d);
void colorcube();
void spinCube();

// matrix functions

// Lighting calculations (flat-shading) done per-quad-vertex, in-app
void quad(int a, int b, int c, int d) 
{
    static int i =0; 
    
    // We need the normal to compute the diffuse term.
    // Calculate normal of triangle plane using cross product of its vertices pairs
    vec4 n1 = GLKVector4Normalize(
                                  GLKVector4CrossProduct(
                                            GLKVector4Subtract(
                                                GLKMatrix4MultiplyVector4(ctm, vertices[b]), 
                                                GLKMatrix4MultiplyVector4(ctm, vertices[a])), 
                                            GLKVector4Subtract(
                                                GLKMatrix4MultiplyVector4(ctm, vertices[c]), 
                                                GLKMatrix4MultiplyVector4(ctm, vertices[b]))));
    vec4 n = GLKVector4Make(n1.x, n1.y, n1.z, 0.0);
    
    // We need the halfway vector for the specular term
    vec4 half = GLKVector4Normalize(GLKVector4Add(light_position, viewer));
    
    color4 ambient_color, diffuse_color, specular_color;
    
    // Each component of the ambient term is the product of the corresponding
    // terms from the ambient light source and the material reflectivity.
    ambient_color = GLKVector4Multiply(material_ambient, light_ambient);
    
    float dd = GLKVector4DotProduct(light_position, n);
    
    if(dd>0.0) diffuse_color = GLKVector4MultiplyScalar(GLKVector4Multiply(light_diffuse, material_diffuse), 
                                                        dd);
    else diffuse_color =  GLKVector4Make(0.0, 0.0, 0.0, 1.0);
    
    dd = GLKVector4DotProduct(half, n);
    if(dd > 0.0) specular_color = GLKVector4MultiplyScalar(GLKVector4Multiply(light_specular, material_specular), 
                                                           exp(material_shininess*log(dd)));
    else specular_color = GLKVector4Make(0.0, 0.0, 0.0, 1.0);
    
    quad_color[i] = GLKVector4Add(ambient_color, diffuse_color);
    points[i] = GLKMatrix4MultiplyVector4(ctm, vertices[a]);
    i++;
    quad_color[i] = GLKVector4Add(ambient_color, diffuse_color);
    points[i] = GLKMatrix4MultiplyVector4(ctm, vertices[b]);
    i++;
    quad_color[i] = GLKVector4Add(ambient_color, diffuse_color);
    points[i] = GLKMatrix4MultiplyVector4(ctm, vertices[c]);
    i++;
    quad_color[i] = GLKVector4Add(ambient_color, diffuse_color);
    points[i] = GLKMatrix4MultiplyVector4(ctm, vertices[a]);
    i++;
    quad_color[i] = GLKVector4Add(ambient_color, diffuse_color);
    points[i] = GLKMatrix4MultiplyVector4(ctm, vertices[c]);
    i++;
    quad_color[i] = GLKVector4Add(ambient_color, diffuse_color);
    points[i] = GLKMatrix4MultiplyVector4(ctm, vertices[d]);
    i++;
    i%=NumVertices;
}

void colorcube()
{
    quad(1,0,3,2);
    quad(2,3,7,6);
    quad(3,0,4,7);
    quad(6,5,1,2);
    quad(4,5,6,7);
    quad(5,4,0,1);
}

void spinCube()
{
    theta[axis] += 0.01;
    if( theta[axis] > 360.0 ) theta[axis] -= 360.0;
}

@interface ViewController () {
    GLuint _program;
    
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation ViewController

@synthesize context = _context;
@synthesize effect = _effect;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
    
    // Setup gesture recognizers with event handlers
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handlePanGesture:)];
    [view addGestureRecognizer:panGesture];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handleDoubleTap:)];
    tapGesture.numberOfTapsRequired = 2;
    [view addGestureRecognizer:tapGesture];
}

- (void)viewDidUnload
{    
    [super viewDidUnload];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
	self.context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glEnable(GL_DEPTH_TEST);
    
    [self loadShaders];
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(points)+sizeof(quad_color), NULL, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 4, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(sizeof(points)));
    
    //glBindVertexArrayOES(0);
    glClearColor(1.0, 1.0, 1.0, 1.0);
    
    // Setup ctm matrix
    ctm.m00 = 1.0f;
    ctm.m11 = 1.0f;
    ctm.m22 = 1.0f;
    ctm.m33 = 1.0f;
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    self.effect = nil;
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    spinCube(); // glutIdleFunc()
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // *** REQUIRED ***
    glUseProgram(_program); 
    
    // *** NOT NEEDED HERE ***
    //glBindVertexArrayOES(_vertexArray);
    
    ctm = GLKMatrix4Multiply(GLKMatrix4MakeXRotation(GLKMathDegreesToRadians(theta[0])), 
                             GLKMatrix4Multiply(GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(theta[1])),
                                                GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(theta[2]))));
    
    //ctm = RotateX(theta[0])*RotateY(theta[1])*RotateZ(theta[2]);
    colorcube();
    
    glBufferSubData( GL_ARRAY_BUFFER, 0, sizeof(points), points );
    glBufferSubData( GL_ARRAY_BUFFER, sizeof(points), sizeof(quad_color), quad_color );
    
    glDrawArrays(GL_TRIANGLES, 0, NumVertices); 
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribColor, "color");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

#pragma mark - UIGestureRecognizer event handlers

// Spins the cube on pan gesture
- (IBAction)handlePanGesture:(UIPanGestureRecognizer *)sender {
    CGPoint translate = [sender translationInView:self.view];
    CGPoint vel = [sender velocityInView:self.view];
    NSLog(@"pan point: %f, %f", translate.x, translate.y);
    NSLog(@"pan velocity: %f, %f", vel.x, vel.y);
    
    if (translate.x > 0) {
        axis = 0;
    } 
    if (translate.y > 0) {
        axis = 1;
    } else {
        axis = 2;
    }
    //theta += translate.x*.01f;
    //phi += translate.y*.01f;
}

- (IBAction)handleDoubleTap:(UITapGestureRecognizer *)sender {
    NSLog(@"double tag detected");
    axis = 0;
}

@end
