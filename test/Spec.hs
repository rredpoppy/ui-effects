import Test.Hspec
import GL.Shader.Fragment.Spec

main :: IO ()
main = hspec $ do
  describe "GL.Shader.Fragment.Spec" $ GL.Shader.Fragment.Spec.spec
