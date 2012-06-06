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
const int  TextureSize  = 64;

// Array of rotation angles (in degrees) for each coordinate axis
enum { Xaxis = 0, Yaxis = 1, Zaxis = 2, NumAxes = 3 };
int      Axis = Xaxis;
int currentTexture = 0;
GLfloat  Theta[NumAxes] = { 0.0, 0.0, 0.0 };
GLuint   theta;

// Vertices of a unit cube centered at origin, sides aligned with axes
point4  vertices[8] = {
    GLKVector4Make( -0.5, -0.5,  0.5, 1.0 ),
    GLKVector4Make( -0.5,  0.5,  0.5, 1.0 ),
    GLKVector4Make(  0.5,  0.5,  0.5, 1.0 ),
    GLKVector4Make(  0.5, -0.5,  0.5, 1.0 ),
    GLKVector4Make( -0.5, -0.5, -0.5, 1.0 ),
    GLKVector4Make( -0.5,  0.5, -0.5, 1.0 ),
    GLKVector4Make(  0.5,  0.5, -0.5, 1.0 ),
    GLKVector4Make(  0.5, -0.5, -0.5, 1.0 )
};

color4 colors[8] = {
    GLKVector4Make( 0.0, 0.0, 0.0, 1.0 ),  // black
    GLKVector4Make( 1.0, 0.0, 0.0, 1.0 ),  // red
    GLKVector4Make( 1.0, 1.0, 0.0, 1.0 ),  // yellow
    GLKVector4Make( 0.0, 1.0, 0.0, 1.0 ),  // green
    GLKVector4Make( 0.0, 0.0, 1.0, 1.0 ),  // blue
    GLKVector4Make( 1.0, 0.0, 1.0, 1.0 ),  // magenta
    GLKVector4Make( 0.0, 1.0, 1.0, 1.0 ),  // white
    GLKVector4Make( 1.0, 1.0, 1.0, 1.0 )   // cyan
};

point4 points[NumVertices];
color4 quad_color[NumVertices];
GLKVector2 tex_coords[NumVertices];

// Texture objects and storage for texture image
GLuint textures[2];

GLubyte image[TextureSize][TextureSize][3];
GLubyte image2[TextureSize][TextureSize][3];

void quad(int a, int b, int c, int d);
void colorcube();
void spinCube();


void quad(int a, int b, int c, int d) 
{
    static int i =0; 
    
    quad_color[i] = colors[a];
    points[i] = vertices[a];
    tex_coords[i] = GLKVector2Make(0.0, 0.0);
    i++;
    quad_color[i] = colors[a];
    points[i] = vertices[b];
    tex_coords[i] = GLKVector2Make(0.0, 1.0);
    i++;
    quad_color[i] = colors[a];
    points[i] = vertices[c];
    tex_coords[i] = GLKVector2Make(1.0, 1.0);
    i++;
    quad_color[i] = colors[a];
    points[i] = vertices[a];
    tex_coords[i] = GLKVector2Make(0.0, 0.0);
    i++;
    quad_color[i] = colors[a];
    points[i] = vertices[c];
    tex_coords[i] = GLKVector2Make(1.0, 1.0);
    i++;
    quad_color[i] = colors[a];
    points[i] = vertices[d];
    tex_coords[i] = GLKVector2Make(1.0, 0.0);
    i++;
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
    Theta[Axis] += 0.2;
    
    if ( Theta[Axis] > 360.0 ) {
        Theta[Axis] -= 360.0;
    }
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
    colorcube();
    
    // Create a checkerboard pattern
    for ( int i = 0; i < TextureSize; i++ ) {
        for ( int j = 0; j < TextureSize; j++ ) {
            GLubyte c = (((i & 0x8) == 0) ^ ((j & 0x8)  == 0)) * 255;
            NSLog(@"texture at %d, %d = %d", i, j, c);
            image[i][j][0]  = c;
            image[i][j][1]  = c;
            image[i][j][2]  = c;
            image2[i][j][0] = c;
            image2[i][j][1] = 0;
            image2[i][j][2] = c;
        }
    }
    [EAGLContext setCurrentContext:self.context];
    
    glEnable(GL_DEPTH_TEST);
    
    // Initialize texture objects
    glGenTextures( 2, textures );
    
    glBindTexture( GL_TEXTURE_2D, textures[0] );
    glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB, TextureSize, TextureSize, 0,
                 GL_RGB, GL_UNSIGNED_BYTE, image );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
    
    glBindTexture( GL_TEXTURE_2D, textures[1] );
    glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB, TextureSize, TextureSize, 0,
                 GL_RGB, GL_UNSIGNED_BYTE, image2 );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
    
    glActiveTexture( GL_TEXTURE0 );
    glBindTexture( GL_TEXTURE_2D, textures[0] );
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    GLintptr offset;
    GLsizeiptr size = sizeof(points) + sizeof(quad_color) + sizeof(tex_coords);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, size, NULL, GL_STATIC_DRAW);
    offset = 0;
    glBufferSubData(GL_ARRAY_BUFFER, offset, sizeof(points), points);
    offset += sizeof(points);
    glBufferSubData(GL_ARRAY_BUFFER, offset, sizeof(quad_color), quad_color);
    offset += sizeof(quad_color);
    glBufferSubData(GL_ARRAY_BUFFER, offset, sizeof(tex_coords), tex_coords);
    
    [self loadShaders];
    
    glUseProgram(_program); 
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 4, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(sizeof(points)));
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, 
                          BUFFER_OFFSET(sizeof(points)+sizeof(colors)));
    
    // Set the value of the fragment shader texture sampler variable
    //   ("texture") to the the appropriate texture unit. In this case,
    //   zero, for GL_TEXTURE0 which was previously set by calling
    //   glActiveTexture().
    glUniform1i( glGetUniformLocation(_program, "texture"), 0 );
    
    theta = glGetUniformLocation(_program, "theta" );

    //glBindVertexArrayOES(0);
    glClearColor(1.0, 1.0, 1.0, 1.0);
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
    spinCube(); // glutIdleFunc()
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // *** REQUIRED ***
    glUseProgram(_program); 
    
    // *** NOT NEEDED HERE ***
    //glBindVertexArrayOES(_vertexArray);
    
    glUniform3fv( theta, 1, Theta );
    
    glDrawArrays( GL_TRIANGLES, 0, NumVertices );
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
    glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "texcoord");
    
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
        Axis = Xaxis;
    } 
    if (translate.y > 0) {
        Axis = Yaxis;
    } else {
        Axis = Zaxis;
    }
    //theta += translate.x*.01f;
    //phi += translate.y*.01f;
}

- (IBAction)handleDoubleTap:(UITapGestureRecognizer *)sender {
    NSLog(@"double tag detected");
    glBindTexture( GL_TEXTURE_2D, textures[currentTexture++] );
    currentTexture %= 2;
}

@end
