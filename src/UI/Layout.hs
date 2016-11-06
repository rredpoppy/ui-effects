{-# LANGUAGE FlexibleInstances, GADTs #-}
module UI.Layout where

import Control.Applicative
import Control.Comonad.Cofree.Cofreer
import Control.Monad.Free.Freer
import Data.Functor.Algebraic
import Data.Functor.Classes
import Data.Functor.Foldable hiding (unfold)
import Data.Maybe (catMaybes, fromMaybe)
import UI.Geometry

data LayoutF a f where
  Inset :: Size a -> f -> LayoutF a f
  Offset :: Point a -> f -> LayoutF a f
  GetMaxSize :: LayoutF a (Size (Maybe a))

type Layout a = Freer (LayoutF a)
type ALayout a b = Cofreer (FreerF (LayoutF a) b)


-- Smart constructors

inset :: Size a -> Layout a b -> Layout a b
inset by = wrap . Inset by

offset :: Real a => Point a -> Layout a b -> Layout a b
offset (Point 0 0) = id
offset by = wrap . Offset by

resizeable :: (Size (Maybe a) -> Layout a b) -> Layout a b
resizeable = (getMaxSize >>=)

getMaxSize :: Layout a (Size (Maybe a))
getMaxSize = liftF GetMaxSize

newtype Stack a b = Stack { unStack :: Layout a b }

stack :: (Real a, Foldable t) => t (Layout a (Size a)) -> Layout a (Size a)
stack = unStack . foldMap Stack


-- Evaluation

measureLayout :: Real a => Layout a (Size a) -> Size a
measureLayout = fromMaybe (Size 0 0) . fitLayoutSize (pure Nothing)

fitLayoutSize :: Real a => Size (Maybe a) -> Layout a (Size a) -> Maybe (Size a)
fitLayoutSize = fitLayoutWith layoutSizeAlgebra

fitLayoutAndAnnotateSize :: Real a => Size (Maybe a) -> Layout a (Size a) -> ALayout a (Size a) (Maybe (Size a))
fitLayoutAndAnnotateSize = fitLayoutWith (annotatingBidi layoutSizeAlgebra)

layoutSizeAlgebra :: Real a => CofreerF (FreerF (LayoutF a) (Size a)) (Point a, Size (Maybe a)) (Maybe (Size a)) -> Maybe (Size a)
layoutSizeAlgebra c@(Cofree (origin, _) _ _) = size <$> layoutAlgebra (fmap (Rect origin) <$> c)


fitLayout :: Real a => Size (Maybe a) -> Layout a (Size a) -> Maybe (Rect a)
fitLayout = fitLayoutWith layoutAlgebra

fitLayoutAndAnnotate :: Real a => Size (Maybe a) -> Layout a (Size a) -> ALayout a (Size a) (Maybe (Rect a))
fitLayoutAndAnnotate = fitLayoutWith (annotatingBidi layoutAlgebra)

layoutAlgebra :: Real a => Algebra (Fitting (LayoutF a) a) (Maybe (Rect a))
layoutAlgebra (Cofree (offset, maxSize) runC layout) = case layout of
  Pure size | maxSize `encloses` size -> Just (Rect offset (fromMaybe <$> size <*> maxSize))
  Free runF layout -> case layout of
    Inset by child -> Rect offset . (2 * by +) . size <$> runC (runF child)
    Offset by child -> Rect offset . (pointSize by +) . size <$> runC (runF child)
    GetMaxSize -> runC (runF maxSize)
  _ -> Nothing
  where maxSize `encloses` size = and (maybe (const True) (>=) <$> maxSize <*> size)


layoutRectanglesAlgebra :: Real a => Algebra (Fitting (LayoutF a) a) [Rect a]
layoutRectanglesAlgebra = wrapAlgebra catMaybes (fmap Just) (collect layoutAlgebra)


type Fitting f a = Bidi f (Size a) (Point a, Size (Maybe a))

fitLayoutWith :: Real a => Algebra (Fitting (LayoutF a) a) b -> Size (Maybe a) -> Layout a (Size a) -> b
fitLayoutWith algebra maxSize layout = hylo algebra fittingCoalgebra (Point 0 0, maxSize, layout)

fittingCoalgebra :: Real a => Coalgebra (Fitting (LayoutF a) a) (Point a, Size (Maybe a), Layout a (Size a))
fittingCoalgebra (offset, maxSize, layout) = Cofree (offset, maxSize) id $ case runFreer layout of
  Pure size -> Pure size
  Free run layout -> case layout of
    Inset by child -> Free id $ Inset by (addSizeToPoint offset by, subtractSize maxSize (2 * by), run child)
    Offset by child -> Free id $ Offset by (liftA2 (+) offset by, subtractSize maxSize (pointSize by), run child)
    GetMaxSize -> Free ((,,) offset maxSize . run) GetMaxSize
  where subtractSize maxSize size = liftA2 (-) <$> maxSize <*> (Just <$> size)
        addSizeToPoint point (Size w h) = liftA2 (+) point (Point w h)


-- Instances

instance Foldable (LayoutF a) where
  foldMap f layout = case layout of
    Inset _ child -> f child
    Offset _ child -> f child
    GetMaxSize -> f (pure Nothing)

instance Real a => Monoid (Stack a (Size a)) where
  mempty = Stack (pure (Size 0 0))
  mappend a b = Stack $ do
    Size w1 h1 <- unStack a
    Size w2 h2 <- unStack b
    pure (Size (max w1 w2) (h1 + h2))

instance (Show a, Show b) => Show (LayoutF a b) where
  showsPrec = liftShowsPrec showsPrec showList

instance Show a => Show1 (LayoutF a) where
  liftShowsPrec sp _ d layout = case layout of
    Inset by child -> showsBinaryWith showsPrec sp "Inset" d by child
    Offset by child -> showsBinaryWith showsPrec sp "Offset" d by child
    GetMaxSize -> showString "GetMaxSize"

instance Eq2 LayoutF where
  liftEq2 eqA eqF l1 l2 = case (l1, l2) of
    (Inset s1 c1, Inset s2 c2) -> liftEq eqA s1 s2 && eqF c1 c2
    (Offset p1 c1, Offset p2 c2) -> liftEq eqA p1 p2 && eqF c1 c2
    (GetMaxSize, GetMaxSize) -> True
    _ -> False

instance Eq a => Eq1 (LayoutF a) where
  liftEq = liftEq2 (==)

instance (Eq a, Eq f) => Eq (LayoutF a f) where
  (==) = liftEq (==)
