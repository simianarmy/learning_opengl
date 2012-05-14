//
//  ViewController.m
//  Perspective Projection
//
//  Perspective view of a color cube using LookAt() and Perspective()
//
//  Created by Marc Mauger on 5/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#include "Angel.h"
#include "mat.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniform index.
enum
{
    UNIFORM_MODELVIEW_MATRIX,
    UNIFORM_PROJECTION_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_COLOR,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};

typedef GLKVector4 color4;
typedef GLKVector4 point4;

// Vertices of a unit cube centered at origin, sides aligned with axes
GLKVector4 vertices[8] = {
    GLKVector4Make( -0.5, -0.5,  0.5, 1.0 ),
    GLKVector4Make( -0.5,  0.5,  0.5, 1.0 ),
    GLKVector4Make(  0.5,  0.5,  0.5, 1.0 ),
    GLKVector4Make(  0.5, -0.5,  0.5, 1.0 ),
    GLKVector4Make( -0.5, -0.5, -0.5, 1.0 ),
    GLKVector4Make( -0.5,  0.5, -0.5, 1.0 ),
    GLKVector4Make(  0.5,  0.5, -0.5, 1.0 ),
    GLKVector4Make(  0.5, -0.5, -0.5, 1.0 )
};

// RGBA colors
GLKVector4 vertex_colors[8] = {
    GLKVector4Make( 0.0, 0.0, 0.0, 1.0 ),  // black
    GLKVector4Make( 1.0, 0.0, 0.0, 1.0 ),  // red
    GLKVector4Make( 1.0, 1.0, 0.0, 1.0 ),  // yellow
    GLKVector4Make( 0.0, 1.0, 0.0, 1.0 ),  // green
    GLKVector4Make( 0.0, 0.0, 1.0, 1.0 ),  // blue
    GLKVector4Make( 1.0, 0.0, 1.0, 1.0 ),  // magenta
    GLKVector4Make( 1.0, 1.0, 1.0, 1.0 ),  // white
    GLKVector4Make( 0.0, 1.0, 1.0, 1.0 )   // cyan
};

// Viewing transformation parameters

GLfloat radius = 1.0f;
GLfloat theta = 0.0f;
GLfloat phi = 0.0f;

const GLfloat  dr = 5.0 * DegreesToRadians;

// Projection transformation parameters
// Frustum() parameters
GLfloat left = -1.0f, right = 1.0f;
GLfloat bottom = -1.0f, top = 1.0f;

// Perspective() paramaters
GLfloat  fovy = 45.0f;  // Field-of-view in Y direction angle (in degrees)
GLfloat  aspect;       // Viewport aspect ratio
GLfloat  zNear = 0.5f, zFar = 30.0f;

point4 triangles [3*464*2*435];

point4 white = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
point4 black = GLKVector4Make(0.0, 0.0, 0.0, 1.0);

void gen_triangles();

void gen_triangles()
{
    float data[465][436];
    int k=0;
    int i, j;
    int n, m;
    float fn, fm, fmax;
    FILE *fp;
    fp = fopen("honolulu.raw", "r");
    fscanf(fp, "%d %d", &n, &m);
    fn = n;
    fm = m;
    for(i=0; i<n; i++) for(j=0; j<m;j++) fscanf(fp, "%f", &data[i][j]);
    float max = data[0][0];
    for(i=0; i<n; i++) for(j=0; j<m;j++) if(data[i][j]>max) max=data[i][j];
    fmax = max;
    for(i=0; i<n-1; i++) for(j=0; j<m-1;j++) 
    {
        triangles[k] = GLKVector4Make(4.0*2.0*(i/fn-0.5), 0.3*data[i][j]/fmax, -4.0*j/fm, 1.0); 
        k++;
        triangles[k] = GLKVector4Make(4.0*2.0*((i+1)/fn-0.5), 0.3*data[i+1][j]/fmax, -4.0*j/fm, 1.0); 
        k++;
        triangles[k] = GLKVector4Make(4.0*2.0*((i+1)/fn-0.5), 0.3*data[i+1][j+1]/fmax, -4.0*(j+1)/fm, 1.0); 
        k++;
        triangles[k] = GLKVector4Make(4.0*2.0*((i+1)/fn-0.5), 0.3*data[i+1][j]/fmax, -4.0*j/fm, 1.0); 
        k++;
        triangles[k] = GLKVector4Make(4.0*2.0*((i+1)/fn-0.5), 0.3*data[i+1][j+1]/fmax, -4.0*(j+1)/fm, 1.0); 
        k++;
        triangles[k] = GLKVector4Make(4.0*2.0*(i/fn-0.5), 0.3*data[i][j+1]/fmax, -4.0*(j+1)/fm, 1.0); 
        k++;
    }
    printf("%d %d %d\n", n, m, k);
}

@interface ViewController () {
    GLuint _program;
    GLint _color_loc;
    
    GLKMatrix4 _modelViewMatrix;
    GLKMatrix4 _projectionMatrix;
    
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
- (IBAction)handlePinchGesture:(UIGestureRecognizer *)sender;
- (IBAction)handlePanGesture:(UIPanGestureRecognizer *)sender;
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
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]
                                              initWithTarget:self action:@selector(handlePinchGesture:)];
    [view addGestureRecognizer:pinchGesture];
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
    gen_triangles();
    
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    // set up vertex buffer
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(triangles), triangles, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 4, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    _color_loc = glGetUniformLocation(_program, "fcolor");
    
    //glBindVertexArrayOES(0);
    glEnable(GL_POLYGON_OFFSET_FILL|GL_DEPTH_TEST);
    glPolygonOffset(1.0, 1.0);
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

#pragma mark - UIGestureRecognizer event handlers

- (IBAction)handlePinchGesture:(UIGestureRecognizer *)sender {
    CGFloat factor = [(UIPinchGestureRecognizer *)sender scale];
    
    if (factor > 1.0) {
        radius *= 2.0;
    } else {
        radius *= 0.5;
    }
//    radius *= factor;
    if (radius >= 6) radius = 6;
    if (radius <= 1) radius = 1;
    NSLog(@"pinch factor: %f, radius: %f", factor, radius);
}

- (IBAction)handlePanGesture:(UIPanGestureRecognizer *)sender {
    CGPoint translate = [sender translationInView:self.view];
    NSLog(@"pan point: %f, %f", translate.x, translate.y);
    theta += translate.x*.01f;
    phi += translate.y*.01f;
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    /*
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    self.effect.transform.projectionMatrix = projectionMatrix;
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
    baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    
    // Compute the model view matrix for the object rendered with GLKit
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    self.effect.transform.modelviewMatrix = modelViewMatrix;
    
    // Compute the model view matrix for the object rendered with ES2
    modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    _rotation += self.timeSinceLastUpdate * 0.5f;
     */
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    GLKVector4 eye = GLKVector4Make(radius*sin(theta)*cos(phi),
                radius*sin(theta)*sin(phi),
                radius*cos(theta),
                1.0 );
    GLKVector4 at = GLKVector4Make( 0.0, 0.0, 0.0, 1.0 );
    GLKVector4 up = GLKVector4Make( 0.0, 1.0, 0.0, 0.0 );
    
    GLKMatrix4 mv = LookAt(eye, at, up);
    //GLKMatrix4 mvtest = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, at.x, at.y, at.z, up.x, up.y, up.z);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, mv.m);
    // glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _modelViewMatrix.m);
    
    //GLKMatrix4 p = Frustum(left, right, bottom, top, zNear, zFar);
    GLKMatrix4 p = Perspective(fovy, aspect, zNear, zFar);
    //GLKMatrix4 ptest = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(fovy), aspect, zNear, zFar);
    glUniformMatrix4fv(uniforms[UNIFORM_PROJECTION_MATRIX], 1, 0, p.m);
    
    // Render the object with GLKit
    //[self.effect prepareToDraw];
    //glDrawArrays(GL_TRIANGLES, 0, NumVertices);    
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    //glBindVertexArrayOES(_vertexArray);
    
    // glPolygonMode is not supported in ES
    // LINEs and POINTs are supported as render primitives (but not as polygon render modes).
    // glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    // TODO: play with glCullFace() and glFrontFace() to test
    glUniform4fv(_color_loc, 1, white.v);
    glDrawArrays(GL_TRIANGLES, 0, 3*435*464*2);
    
    glUniform4fv(_color_loc, 1, black.v);
    glDrawArrays(GL_TRIANGLES, 0, 3*435*464*2);
    
    glFlush();
    
    //glutSwapBuffers();
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
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEW_MATRIX] = glGetUniformLocation(_program, "modelViewMatrix");
    uniforms[UNIFORM_PROJECTION_MATRIX] = glGetUniformLocation(_program, "projectionMatrix");
    
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

@end
