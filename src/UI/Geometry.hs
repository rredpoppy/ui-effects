module UI.Geometry where

import Control.Applicative (liftA, liftA2)
import Data.Functor.Classes
import Data.Functor.Pretty
import Data.Semigroup
import Test.LeanCheck

data Rect a = Rect { origin :: !(Point a), size :: !(Size a) }
  deriving (Eq, Foldable, Functor, Ord, Traversable)
data Point a = Point { x :: !a, y :: !a }
  deriving (Eq, Foldable, Functor, Ord, Traversable)

pointSize :: Point a -> Size a
pointSize (Point x y) = Size x y

data Size a = Size { width :: !a, height :: !a }
  deriving (Eq, Foldable, Functor, Ord, Traversable)

encloses :: Ord a => Size a -> Size a -> Bool
encloses a b = and ((>=) <$> a <*> b)

sizeExtent :: Size a -> Point a
sizeExtent (Size w h) = Point w h


-- Instances

instance Show1 Rect where
  liftShowsPrec sp sl d (Rect origin size) = showsBinaryWith (liftShowsPrec sp sl) (liftShowsPrec sp sl) "Rect" d origin size

instance Show a => Show (Rect a) where
  showsPrec = liftShowsPrec showsPrec showList

instance Eq1 Rect where
  liftEq eq (Rect o1 s1) (Rect o2 s2) = liftEq eq o1 o2 && liftEq eq s1 s2


instance Applicative Point where
  pure a = Point a a
  Point f g <*> Point a b = Point (f a) (g b)

instance Show1 Point where
  liftShowsPrec sp _ d (Point x y) = showsBinaryWith sp sp "Point" d x y

instance Show a => Show (Point a) where
  showsPrec = liftShowsPrec showsPrec showList

instance Eq1 Point where
  liftEq eq (Point x1 y1) (Point x2 y2) = eq x1 x2 && eq y1 y2

instance Pretty1 Point where
  liftPretty p1 (Point x y) = text "Point" </> p1 x </> p1 y

instance Pretty a => Pretty (Point a) where
  pretty = pretty1


instance Applicative Size where
  pure a = Size a a
  Size f g <*> Size a b = Size (f a) (g b)

instance Num a => Num (Size a) where
  fromInteger = pure . fromInteger
  abs = liftA abs
  signum = liftA signum
  negate = liftA negate
  (+) = liftA2 (+)
  (*) = liftA2 (*)

instance Semigroup a => Semigroup (Size a) where
  (<>) = liftA2 (<>)

instance Monoid a => Monoid (Size a) where
  mempty = pure mempty
  mappend = liftA2 mappend

instance Show1 Size where
  liftShowsPrec sp _ d (Size w h) = showsBinaryWith sp sp "Size" d w h

instance Show a => Show (Size a) where
  showsPrec = liftShowsPrec showsPrec showList

instance Eq1 Size where
  liftEq eq (Size w1 h1) (Size w2 h2) = eq w1 w2 && eq h1 h2

instance Listable a => Listable (Size a) where
  tiers = cons2 Size

instance Pretty1 Size where
  liftPretty p1 (Size w h) = text "Size" </> p1 w </> p1 h

instance Pretty a => Pretty (Size a) where
  pretty = pretty1
