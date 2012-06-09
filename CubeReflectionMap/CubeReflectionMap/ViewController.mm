//
//  ViewController.m
//  ShadedCube - reflection-map demo
//
//  Created by Marc Mauger on 5/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

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

point4 points[NumVertices];
point4 normals[NumVertices];

// Texture objects and storage for texture image
GLuint textures[1];

void quad(int a, int b, int c, int d);
void colorcube();
void spinCube();
void checkGLError();

void checkGLError()
{
    GLenum err;
    if ((err = glGetError()) != GL_NO_ERROR ) {
        NSLog(@"oh noes GL error: %d!", err);
    }

}

void quad(int a, int b, int c, int d) 
{
    static int i =0; 
    
    vec4 normal4 = GLKVector4CrossProduct(GLKVector4Subtract(vertices[b], vertices[a]),
                    GLKVector4Subtract(vertices[c], vertices[a]));
    
    vec4 normal = GLKVector4Make(normal4.x, normal4.y, normal4.z, 0.0);
    
    
    normals[i] = normal;
    points[i] = vertices[a];
    i++;
    normals[i] = normal;
    points[i] = vertices[b];
    i++;
    normals[i] = normal;
    points[i] = vertices[c];
    i++;
    normals[i] = normal;
    points[i] = vertices[a];
    i++;
    normals[i] = normal;
    points[i] = vertices[c];
    i++;
    normals[i] = normal;
    points[i] = vertices[d];
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
    Theta[Axis] += 0.2;
    
    if ( Theta[Axis] > 360.0 ) {
        Theta[Axis] -= 360.0;
    }
}

@interface ViewController () {
    GLuint _program;
    
    GLKMatrix4 _modelViewMatrix;
    GLKMatrix4 _projectionMatrix;
    
    float _rotation;
    float _aspect;
    
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
    checkGLError();
    colorcube();
    
    // IOS REQUIRES TEXTURE DIMENSIONS IN POWERS OF 2 ONLY!
    // 2X2 RGB TEXTURE = 12 BYTES
    GLuint tw = 2, th = 2;
    GLubyte red[] = {255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0};
    GLubyte green[] = {0, 255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0};
    GLubyte blue[] = {0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0, 255};
    GLubyte cyan[] = {0, 255, 255, 0, 255, 255, 0, 255, 255, 0, 255, 255};
    GLubyte magenta[] = {255, 0, 255, 255, 0, 255, 255, 0, 255, 255, 0, 255};
    GLubyte yellow[] = {255, 255, 0, 255, 255, 0, 255, 255, 0, 255, 255, 0};

    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    glUseProgram(_program); 
    checkGLError();
    
    glEnable(GL_DEPTH_TEST);
    checkGLError();
    // *** DEPRECATED IN ES2
    // glEnable(GL_TEXTURE_CUBE_MAP);
    // checkGLError();
    
    // Initialize texture objects
    glGenTextures( 1, &textures[0] );
    checkGLError();
    // *** ABSOLUTELY DO NOT USE GL_TEXTURE0!! IT WILL FAIL SILENTLY ***
    glActiveTexture(GL_TEXTURE1);
    checkGLError();
    glBindTexture( GL_TEXTURE_CUBE_MAP, textures[0] );
    checkGLError();
    
    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X ,0,GL_RGB,tw,th,0,GL_RGB,GL_UNSIGNED_BYTE, red);
    glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_X ,0,GL_RGB,tw,th,0,GL_RGB,GL_UNSIGNED_BYTE, green);
    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_Y ,0,GL_RGB,tw,th,0,GL_RGB,GL_UNSIGNED_BYTE, blue);
    glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_Y ,0,GL_RGB,tw,th,0,GL_RGB,GL_UNSIGNED_BYTE, cyan);
    glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_Z ,0,GL_RGB,tw,th,0,GL_RGB,GL_UNSIGNED_BYTE, magenta);
    glTexImage2D(GL_TEXTURE_CUBE_MAP_NEGATIVE_Z ,0,GL_RGB,tw,th,0,GL_RGB,GL_UNSIGNED_BYTE, yellow);
    checkGLError();
    //glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    //glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR); 
    checkGLError();

    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    checkGLError();
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(points) + sizeof(normals), NULL, GL_DYNAMIC_DRAW);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(points), points);
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(points), sizeof(normals), normals);
    checkGLError();
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 4, GL_FLOAT, GL_TRUE, 0, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 4, GL_FLOAT, GL_TRUE, 0, BUFFER_OFFSET(sizeof(points)));
    checkGLError();
    
    // Set the value of the fragment shader texture sampler variable
    //   ("texture") to the the appropriate texture unit. In this case,
    //   zero, for GL_TEXTURE0 which was previously set by calling
    //   glActiveTexture().
    glUniform1i( glGetUniformLocation(_program, "texMap"), textures[0] );
    checkGLError();
    
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
    spinCube(); 
    
    // Adjust projection matrix if aspect ratio changed
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    if (aspect != _aspect) {
        GLfloat left = -2.0, right = 2.0;
        GLfloat top = 2.0, bottom = -2.0;
        GLfloat zNear = -20.0, zFar = 20.0;
        if ( aspect > 1.0 ) {
            left *= aspect;
            right *= aspect;
        }
        else {
            top /= aspect;
            bottom /= aspect;
        }
        glUseProgram(_program);
        _projectionMatrix = GLKMatrix4MakeOrtho(left, right, bottom, top, zNear, zFar);
        glUniformMatrix4fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, GL_FALSE, _projectionMatrix.m);
        checkGLError();
        _aspect = aspect;
    }
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glClearColor(1.0, 1.0, 1.0, 1.0);
    
    // *** REQUIRED ***
    glUseProgram(_program); 
    
    _modelViewMatrix = GLKMatrix4Multiply(GLKMatrix4Multiply(
                                        GLKMatrix4MakeXRotation(GLKMathDegreesToRadians(Theta[0])),
                                          GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Theta[1]))),
                                          GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(Theta[2])));
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewMatrix.m);
    checkGLError();
    // *** NOT NEEDED HERE ***
    //glBindVertexArrayOES(_vertexArray);
        
    glDrawArrays( GL_TRIANGLES, 0, NumVertices );
    checkGLError();
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
    glBindAttribLocation(_program, GLKVertexAttribNormal, "normal");
    
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
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "ModelView");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "Projection");
    
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
