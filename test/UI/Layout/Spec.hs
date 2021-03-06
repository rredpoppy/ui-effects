module UI.Layout.Spec where

import Data.Maybe (fromMaybe, isJust)
import Test.Hspec hiding (shouldBe)
import Test.Hspec.LeanCheck
import UI.Geometry
import UI.Layout hiding (FittingState(..))

spec :: Spec
spec = do
  describe "fitLayout" $ do
    prop "includes only sizes up to the horizontal maximum" $
      \ maxW w -> isJust (fitLayout (Size (Just maxW) Nothing) (pure (Size (w :: Int) 0))) `shouldBe` (maxW >= w)

    prop "includes only sizes up to the vertical maximum" $
      \ maxH h -> isJust (fitLayout (Size Nothing (Just maxH)) (pure (Size 0 (h :: Int)))) `shouldBe` (maxH >= h)

    prop "rejects layouts whose measured size exceeds the maximum" $
      \ maxSize layout -> isJust (fitLayoutSize maxSize layout) `shouldBe` (let measured = measureLayoutSize layout :: Size Int in (fromMaybe <$> measured <*> maxSize) `encloses` measured)

    prop "fills the maximum size" $
      \ maxSize layout -> fitLayoutSize maxSize layout `shouldBe`
        let measured = measureLayoutSize layout :: Size Int in
        if (fromMaybe <$> measured <*> maxSize) `encloses` measured
          then Just (fromMaybe <$> measured <*> maxSize)
          else Nothing

  describe "inset" $ do
    prop "insets the horizontal maximum by twice its margin width" $
      \ maxW w i -> isJust (fitLayout (Size (Just maxW) Nothing) (inset (Size i 0) (pure (Size (w :: Int) 0)))) `shouldBe` (maxW >= w + (2 * i))

    prop "insets the vertical maximum by twice its margin height" $
      \ maxH h i -> isJust (fitLayout (Size Nothing (Just maxH)) (inset (Size 0 i) (pure (Size 0 (h :: Int))))) `shouldBe` (maxH >= h + (2 * i))

    prop "increases size by its inset" $
      \ s1 s2 -> measureLayoutSize (inset s1 (pure s2)) `shouldBe` (2 * s1 + s2 :: Size Int)

  describe "offset" $ do
    prop "reduces the horizontal maximum by its horizontal magnitude" $
      \ maxW w i -> isJust (fitLayout (Size (Just maxW) Nothing) (offset (Point i 0) (pure (Size (w :: Int) 0)))) `shouldBe` (maxW >= w + i)

    prop "reduces the vertical maximum by its vertical magnitude" $
      \ maxH h i -> isJust (fitLayout (Size Nothing (Just maxH)) (offset (Point 0 i) (pure (Size 0 (h :: Int))))) `shouldBe` (maxH >= h + i)

    prop "increases size by its offset" $
      \ p s -> measureLayoutSize (offset p (pure s)) `shouldBe` (pointSize p + s :: Size Int)

  describe "stack" $ do
    prop "takes the sum of its children’s heights" $
      \ a b -> height (measureLayoutSize (stack (pure a) (pure (b :: Size Int)))) `shouldBe` height a + height b

    prop "takes the maximum of its children’s widths" $
      \ a b -> width (measureLayoutSize (stack (pure (a :: Size Int)) (pure b))) `shouldBe` max (width a) (width b)

    prop "arranges its second child after its first" $
      \ a b -> fitLayoutWith layoutRectanglesAlgebra (pure Nothing) (stack (pure a) (pure (b :: Size Int))) `shouldBe`
      [ Rect (Point 0 0) (Size (max (width a) (width b)) (height a + height b))
      , Rect (Point 0 (height a)) (Size (max (width a) (width b)) (height b)) ]

  describe "adjacent" $ do
    prop "takes the sum of its children’s widths" $
      \ a b -> width (measureLayoutSize (adjacent (pure a) (pure (b :: Size Int)))) `shouldBe` width a + width b

    prop "takes the maximum of its children’s heights" $
      \ a b -> height (measureLayoutSize (adjacent (pure (a :: Size Int)) (pure b))) `shouldBe` max (height a) (height b)

    prop "arranges its second child after its first" $
      \ a b -> fitLayoutWith layoutRectanglesAlgebra (pure Nothing) (adjacent (pure a) (pure (b :: Size Int))) `shouldBe`
      [ Rect (Point 0 0) (Size (width a + width b) (max (height a) (height b)))
      , Rect (Point (width a) 0) (Size (width b) (max (height a) (height b))) ]

    prop "arranges aligned layouts" $
      \ a b -> let maxHeight = max (height a) (height b)
                   sumWidths = width (a + b) in
        fitLayoutWith layoutRectanglesAlgebra (Size (Just sumWidths) (Just maxHeight) :: Size (Maybe Int)) (alignLeft (pure a) `adjacent` alignRight (pure b)) `shouldBe`
        [ Rect (Point 0 0) (Size sumWidths maxHeight)
        , Rect (Point 0 0) (Size sumWidths maxHeight)
        , Rect (Point (width a) 0) (Size (width b) maxHeight)
        , Rect (Point (width a) 0) (Size (width b) maxHeight) ]

    prop "alignment distributes over adjacency" $
      \ a b c maxSize -> fitLayout (maxSize :: Size (Maybe Int)) (align a b `adjacent` align a c) `shouldBe` fitLayout maxSize (align a (b `adjacent` c))

  describe "alignLeft" $ do
    prop "minimizes its child’s width" $
      \ s -> (size <$> fitLayoutWith layoutRectanglesAlgebra (Just <$> (s + 2 :: Size Int)) (alignLeft (pure s))) `shouldBe`
      [ s + 2
      , s + Size 0 2 ]

    prop "anchors to the left edge" $
      \ s -> (origin <$> fitLayoutWith layoutRectanglesAlgebra (Just <$> (s + 2 :: Size Int)) (alignLeft (pure s))) `shouldBe`
      [ Point 0 0
      , Point 0 0 ]

    prop "occupies the full available space" $
      \ s -> fitLayoutSize (Just <$> (s + 1 :: Size Int)) (alignLeft (pure s)) `shouldBe`
        Just (s + 1)

  describe "alignRight" $ do
    prop "minimizes its child’s width" $
      \ s -> (size <$> fitLayoutWith layoutRectanglesAlgebra (Just <$> (s + 2 :: Size Int)) (alignRight (pure s))) `shouldBe`
      [ s + 2
      , s + Size 0 2 ]

    prop "anchors to the right edge" $
      \ s -> (origin <$> fitLayoutWith layoutRectanglesAlgebra (Just <$> (s + 2 :: Size Int)) (alignRight (pure s))) `shouldBe`
      [ Point 0 0
      , Point 2 0 ]

    prop "occupies the full available space" $
      \ s -> fitLayoutSize (Just <$> (s + 2 :: Size Int)) (alignRight (pure s)) `shouldBe`
        Just (s + 2)

  describe "alignCentre" $ do
    prop "minimizes its child’s width" $
      \ s -> (size <$> fitLayoutWith layoutRectanglesAlgebra (Just <$> (s + 2 :: Size Int)) (alignCentre (pure s))) `shouldBe`
      [ s + 2
      , s + Size 0 2 ]

    prop "floats its child within the max size" $
      \ s -> (origin <$> fitLayoutWith layoutRectanglesAlgebra (Just <$> (s + 2 :: Size Int)) (alignCentre (pure s))) `shouldBe`
      [ Point 0 0
      , Point 1 0 ]

    prop "occupies the full available space" $
      \ s -> fitLayoutSize (Just <$> (s + 2 :: Size Int)) (alignCentre (pure s)) `shouldBe`
        Just (s + 2)

  describe "alignFull" $ do
    prop "maximizes its child’s width" $
      \ s -> (size <$> fitLayoutWith layoutRectanglesAlgebra (Just <$> (s + 2 :: Size Int)) (alignFull (pure s))) `shouldBe`
      [ s + 2
      , s + 2 ]

    prop "anchors to the left edge" $
      \ s -> (origin <$> fitLayoutWith layoutRectanglesAlgebra (Just <$> (s + 2 :: Size Int)) (alignFull (pure s))) `shouldBe`
      [ Point 0 0
      , Point 0 0 ]

    prop "occupies the full available space" $
      \ s -> fitLayoutSize (Just <$> (s + 2 :: Size Int)) (alignFull (pure s)) `shouldBe`
        Just (s + 2)
