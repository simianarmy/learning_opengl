//
//  ViewController.m
//  Sierpinski3D
//
//  Created by Marc Mauger on 4/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

// Define a helpful macro for handling offsets into buffer objects
#define BUFFER_OFFSET( offset )   ((GLvoid*) (offset))


const int NumTimesToSubdivide = 4;
const int NumTetrahedrons = 256;            // 4^5 tetrahedrons
const int NumTriangles = 4*NumTetrahedrons;  // 4 triangles / tetrahedron
const int NumVertices = 3*NumTriangles;      // 3 vertices / triangle

typedef GLKVector3 vec3;
vec3 points[NumVertices];
vec3 colors[NumVertices];
int Index = 0;

void triangle( const vec3& a, const vec3& b, const vec3& c, const int color );
void tetra( const vec3& a, const vec3& b, const vec3& c, const vec3& d );
void divide_tetra( const vec3& a, const vec3& b,
                  const vec3& c, const vec3& d, int count );

//----------------------------------------------------------------------------

void triangle( const vec3& a, const vec3& b, const vec3& c, const int color )
{
    static vec3  base_colors[] = {
        GLKVector3Make( 1.0, 0.0, 0.0 ),
        GLKVector3Make( 0.0, 1.0, 0.0 ),
        GLKVector3Make( 0.0, 0.0, 1.0 ),
        GLKVector3Make( 0.0, 0.0, 0.0 )
    };
    points[Index] = a;  colors[Index] = base_colors[color];  Index++;
    points[Index] = b;  colors[Index] = base_colors[color];  Index++;
    points[Index] = c;  colors[Index] = base_colors[color];  Index++;
}

//----------------------------------------------------------------------------

void tetra( const vec3& a, const vec3& b, const vec3& c, const vec3& d )
{
    triangle( a, b, c, 0 );
    triangle( a, c, d, 1 );
    triangle( a, d, b, 2 );
    triangle( b, d, c, 3 );
}

//----------------------------------------------------------------------------

void divide_tetra( const vec3& a, const vec3& b,
             const vec3& c, const vec3& d, int count )
{
    if ( count > 0 ) {
        GLKVector3 v0 = GLKVector3DivideScalar(GLKVector3Add(a, b), 2.0);
        GLKVector3 v1 = GLKVector3DivideScalar(GLKVector3Add(a, c), 2.0);
        GLKVector3 v2 = GLKVector3DivideScalar(GLKVector3Add(a, d), 2.0);
        GLKVector3 v3 = GLKVector3DivideScalar(GLKVector3Add(b, c), 2.0);;
        GLKVector3 v4 = GLKVector3DivideScalar(GLKVector3Add(c, d), 2.0);
        GLKVector3 v5 = GLKVector3DivideScalar(GLKVector3Add(b, d), 2.0);
        divide_tetra( a, v0, v1, v2, count - 1 );
        divide_tetra( v0, b, v3, v5, count - 1 );
        divide_tetra( v1, v3, c, v4, count - 1 );
        divide_tetra( v2, v5, v4, d, count - 1 );
    }
    else {
        tetra( a, b, c, d );    // draw tetrahedron at end of recursion
    }
}

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};


@interface ViewController () {
    GLuint _program;
    
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
    vec3 vertices[4] = {
        GLKVector3Make( 0.0, 0.0, -1.0 ),
        GLKVector3Make( 0.0, 0.942809, 0.333333 ),
        GLKVector3Make( -0.816497, -0.471405, 0.333333 ),
        GLKVector3Make( 0.816497, -0.471405, 0.333333 )
    };	
    
    // Subdivide the original tetrahedron
    divide_tetra( vertices[0], vertices[1], vertices[2], vertices[3],
                 NumTimesToSubdivide );

    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(points) + sizeof(colors), NULL, GL_STATIC_DRAW);
    
    // Load the separate arrays of data
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(points), points);
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(points), sizeof(colors), colors);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    // Likewise, initialize the vertex color attribute.  Once again, we
    //    need to specify the starting offset (in bytes) for the color
    //    data.  Just like loading the array, we use "sizeof(points)"
    //    to determine the correct value.
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 3, GL_FLOAT, GL_FALSE, 0, 
                          BUFFER_OFFSET(sizeof(points)));
    
    //glBindVertexArrayOES(0);
    
    glEnable(GL_DEPTH_TEST);
    glClearColor( 1.0, 1.0, 1.0, 1.0 );
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
    
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    //glBindVertexArrayOES(_vertexArray);

    //glDrawArrays( GL_TRIANGLES, 0, NumVertices );
    
    // Render the object with GLKit
    //[self.effect prepareToDraw];
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glDrawArrays( GL_TRIANGLES, 0, NumVertices );
    glFlush();
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
