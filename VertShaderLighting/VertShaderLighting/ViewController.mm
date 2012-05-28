//
//  ViewController.m
//  VertShaderLighting object with lighting calculations in the vertex shader.
//  FAIL FAIL FAIL - LIGHTING DOESN'T WORK
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

typedef GLKVector3 vec3;
typedef GLKVector4 vec4;
typedef GLKVector4 point4;
typedef GLKVector4 color4;
typedef GLKMatrix4 mat4;

const int NumVertices = 36;

// Array of rotation angles (in degrees) for each coordinate axis
enum { Xaxis = 0, Yaxis = 1, Zaxis = 2, NumAxes = 3 };
int      Axis = Xaxis;
GLfloat  Theta[NumAxes] = { 0.0, 0.0, 0.0 };
float nearZ = 0.5f;
float farZ = 3.0f;
bool moved = false;

point4 points[NumVertices];
vec3   normals[NumVertices];

// Vertices of a unit cube centered at origin, sides aligned with axes
point4  vertices[8] = { 
    GLKVector4Make(-0.5,-0.5,0.5, 1.0),
    GLKVector4Make(-0.5,0.5,0.5, 1.0),
    GLKVector4Make(0.5,0.5,0.5, 1.0), 
    GLKVector4Make(0.5,-0.5,0.5, 1.0), 
    GLKVector4Make(-0.5,-0.5,-0.5, 1.0),
    GLKVector4Make(-0.5,0.5,-0.5, 1.0), 
    GLKVector4Make(0.5,0.5,-0.5, 1.0), 
    GLKVector4Make(0.5,-0.5,-0.5, 1.0)};

// quad generates two triangles for each face and assigns colors
//    to the vertices

int Index = 0;

void
quad( int a, int b, int c, int d )
{
    // Initialize temporary vectors along the quad's edge to
    //   compute its face normal 
    vec4 u = GLKVector4Subtract(vertices[b], vertices[a]);
    vec4 v = GLKVector4Subtract(vertices[c], vertices[b]);
    
    vec3 normal = GLKVector3MakeWithArray(GLKVector4Normalize(GLKVector4CrossProduct(u, v)).v);
    
    normals[Index] = normal; points[Index] = vertices[a]; Index++;
    normals[Index] = normal; points[Index] = vertices[b]; Index++;
    normals[Index] = normal; points[Index] = vertices[c]; Index++;
    normals[Index] = normal; points[Index] = vertices[a]; Index++;
    normals[Index] = normal; points[Index] = vertices[c]; Index++;
    normals[Index] = normal; points[Index] = vertices[d]; Index++;
}

//----------------------------------------------------------------------------

// generate 12 triangles: 36 vertices and 36 colors
void
colorcube()
{
    quad( 1, 0, 3, 2 );
    quad( 2, 3, 7, 6 );
    quad( 3, 0, 4, 7 );
    quad( 6, 5, 1, 2 );
    quad( 4, 5, 6, 7 );
    quad( 5, 4, 0, 1 );
}


@interface ViewController () {
    GLuint _program;
    
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
    _aspect = 0;
    
    [self setupGL];
    
    // Setup gesture recognizers with event handlers
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
    colorcube();
    
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
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
    point4 light_position = GLKVector4Make( 1.0, 0.0, -1.0, 0.0 );
    color4 light_ambient = GLKVector4Make( 0.2, 0.2, 0.2, 1.0 );
    color4 light_diffuse = GLKVector4Make( 1.0, 1.0, 1.0, 1.0 );
    color4 light_specular = GLKVector4Make( 1.0, 1.0, 1.0, 1.0 );
    
    color4 material_ambient = GLKVector4Make( 1.0, 0.0, 1.0, 1.0 );
    color4 material_diffuse = GLKVector4Make( 1.0, 0.8, 0.0, 1.0 );
    color4 material_specular = GLKVector4Make( 1.0, 0.8, 0.0, 1.0 );
    float  material_shininess = 100.0;
    
    color4 ambient_product = GLKVector4Multiply(light_ambient, material_ambient);
    color4 diffuse_product = GLKVector4Multiply(light_diffuse, material_diffuse);
    color4 specular_product = GLKVector4Multiply(light_specular, material_specular);
    
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
    
    //glShadeModel(GL_FLAT);
    
    glClearColor( 1.0, 1.0, 1.0, 1.0 ); 

    
    //glBindVertexArrayOES(0);
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
    if (moved || (aspect != _aspect)) {
        GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(45.0f), aspect, nearZ, farZ);
        glUniformMatrix4fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, projectionMatrix.m);
        _aspect = aspect;
    }
    Theta[Axis] += 0.5;
    
    if ( Theta[Axis] > 360.0 ) {
        Theta[Axis] -= 360.0;
    }
    _rotation += self.timeSinceLastUpdate * 0.5f;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    const vec3 view_pos = GLKVector3Make(0.0, 0.0, 2.0);
    GLKMatrix4 tran = GLKMatrix4MakeTranslation(-view_pos.x, -view_pos.y, -view_pos.z);
    GLKMatrix4 rot = GLKMatrix4Multiply(GLKMatrix4Multiply(
                                            GLKMatrix4MakeXRotation(GLKMathDegreesToRadians(Theta[Xaxis])), 
                                            GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Theta[Yaxis]))),
                                        GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(Theta[Zaxis])));
    GLKMatrix4 mv = GLKMatrix4Multiply(tran, rot);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, mv.m);
    
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
        farZ *= 1.1;
    } else {
        nearZ *= 0.9;
        farZ *= 0.9;
    }
    moved = true;
    NSLog(@"pinch factor: %f", factor);
}

- (IBAction)handleDoubleTap:(UITapGestureRecognizer *)sender {
    NSLog(@"double tag detected");
    nearZ = 0.5f;
    farZ = 3.5f;
    moved = true;
}

@end
