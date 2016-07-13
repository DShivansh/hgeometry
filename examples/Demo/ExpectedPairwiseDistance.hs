{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Demo.ExpectedPairwiseDistance where

import           Algorithms.Geometry.WellSeparatedPairDecomposition.Types
import           Algorithms.Geometry.WellSeparatedPairDecomposition.WSPD
import           Control.Lens
import Data.Proxy
import GHC.TypeLits(natVal,KnownNat)
import           Data.BinaryTree
import qualified Data.ByteString       as B
import qualified Data.ByteString.Char8 as C
import           Data.Char (isSpace)
import           Data.Ext
import           Data.Geometry
import qualified Data.List.NonEmpty as NonEmpty
import           Data.Maybe (mapMaybe)
import           Data.Semigroup

import Debug.Trace

--------------------------------------------------------------------------------

-- | Evaluates the formula: $\sum_{p,q \in pts} \|pq\|*Prb[sample has size k
-- and contains p and q]$ which solves to $\frac{{n-2 \choose k-2}}{{n \choose
-- k}} \sum_{p,q} \|pq\|$
--
-- running time: $O(n^2)$, where $n$ is the number of points
expectedPairwiseDistance       :: (Floating r, Arity d) => Int -> [Point d r :+ p] -> r
expectedPairwiseDistance k pts = makeExpected k pts pairwiseDist

-- | A $(1+\varepsilon)$-approximation of expectedPairwiseDistance
--
-- running time: $O(n(1/eps)^d + n\log n)$, where $n$ is the number of points
approxExpectedPairwiseDistance          :: (Floating r, Ord r
                                           , AlwaysTrueWSPD d, Index' 0 d
                                         , Show r, Show p)
                                         => r -> Int -> [Point d r :+ p] -> r
approxExpectedPairwiseDistance eps k pts =
  makeExpected k pts (approxPairwiseDistance eps)

--------------------------------------------------------------------------------
-- * Computing Distances

-- | Sum of the pairwise distances
pairwiseDist     :: (Floating r, Arity d) => [Point d r :+ p] -> r
pairwiseDist pts = sum [ euclideanDist (p^.core) (q^.core) | p <- pts, q <- pts]


-- | $(1+\eps)$-approximation of the sum of the pairwise distances.
--
-- running time: $O(n(1/eps)^d + n\log n)$, where $n$ is the number of points
approxPairwiseDistance         :: (Floating r, Ord r, AlwaysTrueWSPD d, Index' 0 d
                                  , Show r, Show p)
                               => r -> [Point d r :+ p] -> r
approxPairwiseDistance _   []  = 0
approxPairwiseDistance eps pts =
    sum [ (size as)*(size bs)*euclideanDist (repr as) (repr bs) | (as,bs) <- pairs ]
  where
    t     = withSizes . fairSplitTree . NonEmpty.fromList $ pts
    pairs = wellSeparatedPairs (4 / eps) t
      -- TODO: Check the 4!!!

    size (access -> (Sized (Size i) _))  = fromIntegral i
    repr (access -> (Sized _ (First p))) = p^.core


--------------------------------------------------------------------------------
-- * Helper stuff

-- | Helper to turn the result of 'f k' into 'the expected 'f k', assuming that
-- we select a set of k points.
makeExpected         :: (Fractional r, Foldable t) => Int -> t a -> (t a -> r) -> r
makeExpected k pts f = prb * f pts
  where
    n   = length pts
    prb = ((n - 2) `choose` (k - 2)) / (n `choose` k)


choose       :: (Integral a, Num b) => a -> a -> b
n `choose` k = fromIntegral $ fac n' `div` (fac (n'-k') * fac k')
  where
    n' :: Integer
    n' = fromIntegral n
    k' :: Integer
    k' = fromIntegral k

    fac z = product [1..z]

-- newtype WSPDMeasured a = WSPDMeasured a

-- instance Measured (Sized (First a)) (WSPDMeasured a) where
--   measure (WSPDMeasured p) = Sized 1 (First p)

-- instance Measured v (WSPDMeasured (Point d r :+ p))
--            => Measured v (SplitTree d p r v) where
--   measure (Leaf p)      = measure $ WSPDMeasured p
--   measure (Node _ nd _) = nd^.nodeData

-- | Annotate the split tree with sizes
withSizes :: SplitTree d p r a -> SplitTree d p r (Sized (First (Point d r :+ p)))
withSizes = foldUp f Leaf
  where
    f l (NodeData j b _) r = let nd = (access l) <> (access r)
                             in Node l (NodeData j b nd) r

-- | Get the measurement for a given splittree
access               :: BinLeafTree (NodeData d r (Sized (First a))) a -> Sized (First a)
access (Leaf x)      = Sized 1 (First x)
access (Node _ nd _) = nd^.nodeData


--
-- | CVS file, in which every line consists of a name, followed by exactly d coordinates
parseInput :: forall d r. (Arity d, KnownNat d, Read r)
           => B.ByteString -> [Point d r :+ B.ByteString]
parseInput = mapMaybe toPoint . drop 1 . C.lines
  where
    trim      = fst . C.spanEnd isSpace . C.dropWhile isSpace
    fromList' = vectorFromList . take (fromInteger . natVal $ (Proxy :: Proxy d))

    toPoint bs = let (n:rs) = map trim . C.split ',' $ bs
                     p      = fmap Point . fromList' . map (read . C.unpack) $ rs
                 in (:+ n) <$> p


readInput :: (Arity d, KnownNat d, Read r) => FilePath -> IO [Point d r :+ C.ByteString]
readInput = fmap parseInput . B.readFile

test :: FilePath -> IO [Point 3 Double :+ C.ByteString]
test = readInput
