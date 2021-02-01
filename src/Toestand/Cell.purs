-- | The Cell is essentially a mutable value held in a react ref with
-- | some added state management features:
-- |
-- | * Listen for changes to the value.
-- | * Selectively alert listeners when the value has changed.
-- | * Selectively refresh the component when the value changes.
module Toestand.Cell
  ( module Toestand.Watches
  , Cell, ShouldRefresh, listen, read, useCell, write
  ) where

import Prelude (Unit, (<$>), (>>=), ($), (+), bind, discard, pure)
import Control.Applicative (when)
import Effect (Effect)
import Data.Tuple (snd)
import Reactix as R
import Toestand.Watches as W
import Toestand.Watches (Listener, ShouldNotify)

type ShouldRefresh c = ShouldNotify c

-- | A flexible mutable wrapper for state based around a react
-- | ref. See module documentation for more.
newtype Cell c = Cell (R.Ref (Cell' c))

type Cell' c =
  { value         :: c
  , refresh       :: R.Setter Int
  , shouldRefresh :: ShouldRefresh c
  , watches       :: W.Watches c
  }

-- | A hook which allocates a Cell, a flexible mutable wrapper for
-- | state utilising a react ref. Will refresh the component when the
-- | should refresh predicate returns true.
useCell :: forall c. ShouldRefresh c -> ShouldNotify c -> c -> R.Hooks (Cell c)
useCell shouldRefresh shouldNotify value = do
  refresh <- snd <$> R.useState' 0
  watches <- R.unsafeHooksEffect $ W.new shouldNotify
  Cell <$> R.useRef { value, refresh, shouldRefresh, watches }

-- | Read the current value in the cell. Can be called in either Hooks or Effect
read :: forall m c. R.MonadDelay m => Cell c -> m c
read (Cell ref) = (_.value) <$> R.readRefM ref

-- | Replace the value held in the cell without regard to its current value.
write :: forall c. c -> Cell c -> Effect c
write value (Cell ref) = do
  cell <- R.readRefM ref
  let new = cell { value = value }
  R.setRef ref new
  W.notify cell.watches value cell.value
  when (cell.shouldRefresh { new: value, old: cell.value }) (cell.refresh (_ + 1))
  pure value

-- | Run an Effectful function when a change occurs. Returns a cancel effect.
listen :: forall c. Cell c -> Listener c -> Effect (Effect Unit)
listen (Cell ref) l = R.readRefM ref >>= \cell -> W.listen cell.watches l
