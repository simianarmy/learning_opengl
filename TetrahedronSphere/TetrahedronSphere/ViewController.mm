//
//  ViewController.m
//  TetrahedronSphere
//
//  Created by Marc Mauger on 5/27/12.
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

#define N 4  // number of subdivisions
#define M 16*64*3  // number of resulting points

GLsizei w=512, h=512;

typedef GLKVector4 point4;
typedef GLKVector4 vec4;
typedef GLKMatrix4 mat4;

point4 data[M];

// four equally spaced points on the unit circle

point4 v[4]= {GLKVector4Make(0.0, 0.0, 1.0, 1.0), 
    GLKVector4Make(0.0, 0.942809, -0.333333, 1.0),
    GLKVector4Make(-0.816497, -0.471405, -0.333333, 1.0),
    GLKVector4Make(0.816497, -0.471405, -0.333333, 1.0)};

float theta = 0.0;
float phi = 0.0;
float radius = 2.0;
static int k =0;

point4 at = GLKVector4Make(0.0, 0.0, 0.0, 1.0);
point4 eye = GLKVector4Make(0.0, 0.0, 2.0, 1.0);
vec4 up = GLKVector4Make(0.0, 1.0, 0.0, 0.0);

GLfloat left= -2.0, right=2.0, top=2.0, bottom= -2.0, nearZ= -4.0, farZ=4.0;
float dr = 3.14159/180.0*5.0;

// Vertex-generation

// move a point to unit circle

point4 unit(const point4 &p)
{
    point4 c;
    double d=0.0;
    for(int i=0; i<3; i++) d+=p.v[i]*p.v[i];
    d=sqrt(d);
    if(d > 0.0) for(int i=0; i<3; i++) c.v[i] = p.v[i]/d;
    c.w = 1.0;
    return c;
}

void triangle( point4  a, point4 b, point4 c)
{
    data[k]= a;
    k++;
    data[k] = b;
    k++;
    data[k] = c;
    k++;
}


void divide_triangle(point4 a, point4 b, point4 c, int n)
{
    point4 v1, v2, v3;
    if(n>0)
    {
        v1 = unit(GLKVector4Add(a, b));
        v2 = unit(GLKVector4Add(a, c));
        v3 = unit(GLKVector4Add(b, c));   
        divide_triangle(a ,v2, v1, n-1);
        divide_triangle(c ,v3, v2, n-1);
        divide_triangle(b ,v1, v3, n-1);
        divide_triangle(v1 ,v2, v3, n-1);
    }
    else triangle(a, b, c);
}

void tetrahedron(int n)
{
    divide_triangle(v[0], v[1], v[2] , n);
    divide_triangle(v[3], v[2], v[1], n );
    divide_triangle(v[0], v[3], v[1], n );
    divide_triangle(v[0], v[3], v[2], n );
}



@interface ViewController () {
    GLuint _program;
    
    float _rotation;
    
    GLKMatrix4 _modelViewProjectionMatrix;
    
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
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]
                                              initWithTarget:self action:@selector(handlePinchGesture:)];
    [view addGestureRecognizer:pinchGesture];
    
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
    tetrahedron(N);
    
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 4, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glBindVertexArrayOES(0);
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
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    
    theta += 0.01;
    phi += 0.01;
    if (theta >= 360.0) { theta = 0; }
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    GLKMatrix4 lookAt = GLKMatrix4MakeLookAt(radius*sin(theta)*cos(phi), 
                                                      radius*sin(theta)*sin(phi), 
                                                      radius*cos(theta), 
                                                      0, 0, 0, 
                                                      0, 1.0f, 0);
    GLKMatrix4 ortho = GLKMatrix4MakeOrtho(left, right, bottom, top, nearZ, farZ);
    _modelViewProjectionMatrix = GLKMatrix4Multiply(ortho, lookAt);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    
    for(int i = 0; i<M; i+=3) glDrawArrays(GL_LINE_LOOP, i, 3);
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
    glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    
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
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    
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

- (IBAction)handlePinchGesture:(UIGestureRecognizer *)sender {
    CGFloat factor = [(UIPinchGestureRecognizer *)sender scale];
    
    if (factor > 1.0) {
        nearZ *= 1.1;
        farZ *= 1.2;
    } else {
        nearZ *= 0.9;
        farZ *= 0.9;
    }
    NSLog(@"pinch factor: %f", factor);
}

- (IBAction)handlePanGesture:(UIPanGestureRecognizer *)sender {
    CGPoint translate = [sender translationInView:self.view];
    CGPoint vel = [sender velocityInView:self.view];
    NSLog(@"pan point: %f, %f", translate.x, translate.y);
    NSLog(@"pan velocity: %f, %f", vel.x, vel.y);
    
    if (translate.x > 0) {
        radius *= 1.1;
        left *= 1.1;
        right *= 1.1;
    } else {
        radius *= 0.9;
        left *= 0.9;
        right *= 0.9;
    }
    if (translate.y > 0) {
        if (vel.x > 1) {
            theta += dr;
            bottom *= 1.1;
        } else {
            phi += dr;
            top *= 1.1;
        }
    } else {
        if (vel.x > 1) {
            theta -= dr;
            bottom *= 0.9;
        } else {
            phi -= dr;
            top *= 0.9;
        }
    }
    //theta += translate.x*.01f;
    //phi += translate.y*.01f;
}

- (IBAction)handleDoubleTap:(UITapGestureRecognizer *)sender {
    NSLog(@"double tag detected");
    left = -1.0;
    right = 1.0;
    bottom = -1.0;
    top = 1.0;
    nearZ = -4.0;
    farZ = 4.0;
    radius = 1.0;
    theta = 0.0;
    phi = 0.0;
}


@end
