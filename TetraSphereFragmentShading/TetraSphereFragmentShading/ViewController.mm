//
//  ViewController.m
//  TetraSphereFragmentShading
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

const int NumTimesToSubdivide = 5;
const int NumTriangles        = 4096;  // (4 faces)^(NumTimesToSubdivide + 1)
const int NumVertices         = 3 * NumTriangles;

GLsizei w=512, h=512;

typedef GLKVector3 vec3;
typedef GLKVector4 vec4;
typedef GLKVector4 point4;
typedef GLKVector4 color4;
typedef GLKMatrix4 mat4;

point4 points[NumVertices];
vec3   normals[NumVertices];

float theta = 0.0;
float phi = 0.0;
float radius = 2.0;
static int k =0;

point4 at = GLKVector4Make(0.0, 0.0, 0.0, 1.0);
point4 eye = GLKVector4Make(0.0, 0.0, 2.0, 1.0);
vec4 up = GLKVector4Make(0.0, 1.0, 0.0, 0.0);

GLfloat left= -2.0, right=2.0, top=2.0, bottom= -2.0, nearZ= -4.0, farZ=4.0;
float dr = 3.14159/180.0*5.0;

int Index = 0;

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
    vec3  normal = GLKVector3MakeWithArray(GLKVector4Normalize(GLKVector4CrossProduct(
                                        GLKVector4Subtract(b, a), 
                                        GLKVector4Subtract(c, b))).v);
    
    normals[Index] = normal;  points[Index] = a;  Index++;
    normals[Index] = normal;  points[Index] = b;  Index++;
    normals[Index] = normal;  points[Index] = c;  Index++;
}


void divide_triangle(point4 a, point4 b, point4 c, int n)
{
    point4 v1, v2, v3;
    if(n>0)
    {
        v1 = unit(GLKVector4Add(a, b));
        v2 = unit(GLKVector4Add(a, c));
        v3 = unit(GLKVector4Add(b, c));   
        divide_triangle(a ,v1, v2, n-1);
        divide_triangle(c ,v2, v3, n-1);
        divide_triangle(b ,v3, v1, n-1);
        divide_triangle(v1 ,v3, v2, n-1);
    }
    else triangle(a, b, c);
}

void tetrahedron(int n)
{
    // four equally spaced points on the unit circle
    
    point4 v[4]= {GLKVector4Make(0.0, 0.0, 1.0, 1.0), 
        GLKVector4Make(0.0, 0.942809, -0.333333, 1.0),
        GLKVector4Make(-0.816497, -0.471405, -0.333333, 1.0),
        GLKVector4Make(0.816497, -0.471405, -0.333333, 1.0)};

    divide_triangle(v[0], v[1], v[2] , n);
    divide_triangle(v[3], v[2], v[1], n );
    divide_triangle(v[0], v[3], v[1], n );
    divide_triangle(v[0], v[2], v[3], n );
}



@interface ViewController () {
    GLuint _program;
    
    float _rotation;
    float _aspect;
    
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
    _aspect = 0;
    
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
    tetrahedron(NumTimesToSubdivide);
    
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(points)+sizeof(normals), NULL, GL_STATIC_DRAW);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(points), points);
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(points), sizeof(normals), normals);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 4, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(sizeof(points)));
    
    // Initialize shader lighting parameters
    point4 light_position = GLKVector4Make( -3.0, 1.0, 2.0, 0.0 );
    color4 light_ambient = GLKVector4Make( 0.2, 0.2, 0.2, 1.0 );
    color4 light_diffuse = GLKVector4Make( 1.0, 1.0, 1.0, 1.0 );
    color4 light_specular = GLKVector4Make( 1.0, 1.0, 1.0, 1.0 );
    
    color4 material_ambient = GLKVector4Make( 1.0, 0.0, 1.0, 1.0 );
    color4 material_diffuse = GLKVector4Make( 1.0, 0.8, 0.0, 1.0 );
    color4 material_specular = GLKVector4Make( 1.0, 0.0, 1.0, 1.0 );
    float  material_shininess = 5.0;
    
    color4 ambient_product = GLKVector4Multiply(light_ambient, material_ambient);
    color4 diffuse_product = GLKVector4Multiply(light_diffuse, material_diffuse);
    color4 specular_product = GLKVector4Multiply(light_specular, material_specular);
    
    // *** IMPORTANT ***
    // glUseProgram() MUST be called before any glUniform* calls!
    glUseProgram(_program);
    
    glUniform4fv( glGetUniformLocation(_program, "AmbientProduct"),
                 1, ambient_product.v );
    glUniform4fv( glGetUniformLocation(_program, "DiffuseProduct"),
                 1, diffuse_product.v );
    glUniform4fv( glGetUniformLocation(_program, "SpecularProduct"),
                 1, specular_product.v );
    
    glUniform4fv( glGetUniformLocation(_program, "LightPosition"),
                 1, light_position.v );
    
    glUniform1f( glGetUniformLocation(_program, "Shininess"),
                material_shininess );
    
    glEnable( GL_DEPTH_TEST );

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
        GLKMatrix4 proj = GLKMatrix4MakeOrtho(left, right, bottom, top, zNear, zFar);
        glUniformMatrix4fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, GL_FALSE, proj.m);
        _aspect = aspect;
    }
    _rotation += 0.1;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    GLKMatrix4 lookAt = GLKMatrix4MakeLookAt(0.0, 0.0, 2.0,
                                             0.0, 0.0, 0.0,
                                             0.0, 1.0, 0.0);
    GLKMatrix4 rot = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(_rotation));
    GLKMatrix4 mv = GLKMatrix4Multiply(lookAt, rot);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, mv.m);
    
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
    glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIB_NORMAL, "normal");
    
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
