{-# LANGUAGE OverloadedStrings #-}

module Simple where

import Control.Monad      (foldM)
import Data.List.NonEmpty
import Data.Text          (Text)
import Text.Printf        (printf)

import qualified PaymentProvider
import           Checkout        ( Card(..)
                                 , CartItem(..)
                                 , calculatePrice
                                 )

data CheckoutState
  = NoItems
  | HasItems (NonEmpty CartItem)
  | NoCard (NonEmpty CartItem)
  | CardSelected (NonEmpty CartItem)
                 Card
  | CardConfirmed (NonEmpty CartItem)
                  Card
  | OrderPlaced
  deriving (Show, Eq)

data CheckoutEvent
  = Select CartItem
  | Checkout
  | SelectCard Card
  | Confirm
  | PlaceOrder
  | Cancel
  deriving (Show, Eq)

type FSM s e = 
   s -> e -> IO s

checkout :: FSM CheckoutState CheckoutEvent
checkout NoItems (Select item) =
  return (HasItems (item :| []))

checkout (HasItems items) (Select item) =
  return (HasItems (item <| items))

checkout (HasItems items) Checkout =
  return (NoCard items)

checkout (NoCard items) (SelectCard card) =
  return (CardSelected items card)

checkout (CardSelected items card) Confirm =
  return (CardConfirmed items card)

checkout state Cancel =
  case state of
    NoCard items          -> return (HasItems items)
    CardSelected items _  -> return (HasItems items)
    CardConfirmed items _ -> return (HasItems items)
    _                     -> return state

checkout (CardConfirmed items card) PlaceOrder = do
  PaymentProvider.chargeCard card (calculatePrice items)
  return OrderPlaced

checkout state _ = return state

runFsm :: Foldable f => FSM s e -> s -> f e -> IO s
runFsm = foldM

withLogging
  :: (Show s, Show e)
  => FSM s e
  -> FSM s e
withLogging fsm s e = do
  s' <- fsm s e
  printf "- %s × %s → %s\n" (show s) (show e) (show s')
  return s'

main = runFsm
   (withLogging checkout)
   NoItems
   [ Select (CartItem "potatoes" 23.95)
   , Confirm
   , PlaceOrder
   , Checkout
   , Select (CartItem "fish" 168.50)
   , SelectCard (Card "0000-0000-0000-0000")
   ]
