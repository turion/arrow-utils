{-# LANGUAGE Arrows #-}

module Control.Arrow.Utils (
    SameInputArrow
  , unSameInputArrow
  , sequenceArr_
  , sequenceArr
  , sequenceArrVec
  , sequenceArrList
  , whenA
  , unlessA
  , constantly
) where

import Control.Arrow
    ( returnA, (>>>), Arrow((***), arr), ArrowChoice )
import Data.Foldable (traverse_)
import Data.Maybe ( fromJust )
import Data.Vector.Sized ( fromList, toList, Vector )
import GHC.TypeLits ( KnownNat )


-- | Wrap the Arrow in a newtype in order to create new class instances
newtype SameInputArrow a b c = SameInputArrow { unSameInputArrow :: a b c }

-- | A group of arrows which all take the same input is a Functor
instance (Arrow a) => Functor (SameInputArrow a b) where
  fmap f a = SameInputArrow (unSameInputArrow a >>> arr f)

-- | A group of arrows which all take the same input is an Applicative
instance (Arrow a) => Applicative (SameInputArrow a b) where
  pure c = SameInputArrow $ arr (const c)
  f <*> a = SameInputArrow $ proc input -> do
    fres <- unSameInputArrow f -< input
    ares <- unSameInputArrow a -< input
    returnA -< fres ares

sequenceArr_ :: (Foldable t, Arrow a) => t (a b1 b2) -> a b1 ()
sequenceArr_ xs = unSameInputArrow $ traverse_ SameInputArrow xs

sequenceArr :: (Traversable t, Arrow a1) => t (a1 b a2) -> a1 b (t a2)
sequenceArr xs = unSameInputArrow $ traverse SameInputArrow xs

sequenceArrVec :: (Arrow a, KnownNat n) => Vector n (a b c) -> a (Vector n b) (Vector n c)
sequenceArrVec cells = arr toList >>> sequenceArrListUnsafe (toList cells) >>> arr (fromJust . fromList)

-- not safe, doesn't check size of lists
-- when used in sequenceArrVec it is safe as the size of the
-- vectors are all the same
sequenceArrListUnsafe :: Arrow a => [a b1 b2] -> a [b1] [b2]
sequenceArrListUnsafe [] = arr (const [])
sequenceArrListUnsafe (x:xs) = proc (y:ys) -> do
  xres <- x -< y
  xsres <- sequenceArrListUnsafe xs -< ys
  returnA -< (xres:xsres)

-- | Fans each input from @[b1]@ to a separate arrow from the given list.
--   The output list has length of the minimum of the input list length and the arrow list length.
sequenceArrList :: (Arrow a, ArrowChoice a) => [a b c] -> a [b] [c]
sequenceArrList [] = arr $ const []
sequenceArrList (a : as) = proc bs' -> case bs' of
  [] -> returnA -< []
  b : bs -> do
    c <- a -< b
    cs <- sequenceArrList as -< bs
    returnA -< c : cs

whenA :: ArrowChoice a => a b () -> a (Bool, b) ()
whenA cell = proc (b, input) -> do
  if b
    then cell -< input
    else arr (const ()) -< input

unlessA :: ArrowChoice a => a b () -> a (Bool, b) ()
unlessA cell = arr not *** arr id >>> whenA cell

-- | Always output the given value.
constantly :: Arrow a => b -> a any b
constantly = arr . const
