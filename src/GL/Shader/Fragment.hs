{-# LANGUAGE GADTs, MultiParamTypeClasses #-}
module GL.Shader.Fragment where

import Control.Exception
import Control.Monad
import Data.Foldable (for_)
import Data.List (intercalate)
import Data.Monoid
import Data.Typeable
import Foreign.C.String
import Foreign.Marshal.Alloc
import Foreign.Ptr
import Foreign.Storable
import Graphics.GL.Core41
import Graphics.GL.Types
import Graphics.Shader.Fragment
import Linear.V3

newtype Shader = Shader { unShader :: GLuint }

newtype Program = Program { unProgram :: GLuint }

newtype VAO = VAO { unVAO :: GLuint }

newtype ShaderException = ShaderException String
  deriving (Show, Typeable)

newtype ProgramException = ProgramException String
  deriving (Show, Typeable)

toGLSL :: Fragment () -> String
toGLSL shader
  = pragma "version" "410"
  <> "out vec4 fragColour;\n"
  <> main (go shader)
  where go :: Fragment a -> String
        go (SetColour c) = "  fragColour = " <> go c <> ";\n"
        go (V4 x y z w) = "vec4(" <> intercalate ", " (show <$> [ x, y, z, w ]) <> ")"
        go (V2 x y) = "vec2(" <> intercalate ", " (show <$> [ x, y ]) <> ")"
        go (Add a b) = go a <> " + " <> go b
        go (Mul a b) = go a <> " * " <> go b
        go (Sub a b) = go a <> " - " <> go b
        go (Div a b) = go a <> " / " <> go b
        go _ = ""
        pragma k v = "#" <> k <> " " <> v <> "\n"
        main body = "void main(void) {\n" <> body <> "}"


withVertices :: [V3 Float] -> (VAO -> IO a) -> IO a
withVertices vertices body = alloca $ \ p -> do
  glGenBuffers 1 p
  vbo <- peek p
  let bytes = length vertices * 3 * sizeOf (0 :: Float)
  allocaBytes bytes $ \ p -> do
    for_ (zip [0..] vertices) (uncurry (pokeElemOff p))
    glBindBuffer GL_ARRAY_BUFFER vbo
    glBufferData GL_ARRAY_BUFFER (fromIntegral bytes) (castPtr p) GL_STATIC_DRAW
  glGenVertexArrays 1 p
  vao <- peek p
  glBindVertexArray vao
  glEnableVertexAttribArray 0
  glBindBuffer GL_ARRAY_BUFFER vbo
  glVertexAttribPointer 0 3 GL_FLOAT GL_FALSE 0 nullPtr
  body $ VAO vao

withCompiledShader :: GLenum -> String -> (Shader -> IO a) -> IO a
withCompiledShader shaderType source body = bracket
  (glCreateShader shaderType)
  glDeleteShader
  (\ shader -> do
    withCString source $ \ source ->
      alloca $ \ p -> do
        poke p source
        glShaderSource shader 1 p nullPtr
    glCompileShader shader
    s <- checkShader (Shader shader)
    body s)

withCompiledShaders :: [(GLenum, String)] -> ([Shader] -> IO a) -> IO a
withCompiledShaders sources body = traverse (flip (uncurry withCompiledShader) pure) sources >>= body


withLinkedProgram :: [Shader] -> (Program -> IO a) -> IO a
withLinkedProgram shaders body = bracket
  glCreateProgram
  glDeleteProgram
  (\ program -> do
    for_ shaders (glAttachShader program . unShader)
    glLinkProgram program
    for_ shaders (glDetachShader program . unShader)
    p <- checkProgram (Program program)
    body p)


withBuiltProgram :: [(GLenum, String)] -> (Program -> IO a) -> IO a
withBuiltProgram sources body = withCompiledShaders sources (`withLinkedProgram` body)


checkShader :: Shader -> IO Shader
checkShader = fmap Shader . checkStatus glGetShaderiv glGetShaderInfoLog ShaderException GL_COMPILE_STATUS . unShader

checkProgram :: Program -> IO Program
checkProgram = fmap Program . checkStatus glGetProgramiv glGetProgramInfoLog ProgramException GL_LINK_STATUS . unProgram

checkStatus :: Exception e => (GLenum -> GLuint -> Ptr GLint -> IO ()) -> (GLuint -> GLsizei -> Ptr GLsizei -> Ptr GLchar -> IO ()) -> (String -> e) -> GLenum -> GLuint -> IO GLuint
checkStatus get getLog exception status object = do
  success <- alloca $ \ p -> do
    get object status p
    peek p
  when (success == GL_FALSE) $ do
    l <- alloca $ \ p -> do
      get object GL_INFO_LOG_LENGTH p
      peek p
    log <- allocaBytes (fromIntegral l) $ \ bytes -> do
      getLog object l nullPtr bytes
      peekCString bytes
    throw $ exception log
  pure object


instance Exception ShaderException
instance Exception ProgramException
