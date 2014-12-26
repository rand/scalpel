{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ParallelListComp #-}
{-# LANGUAGE PatternGuards #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}
module Text.HTML.Scalpel (
    Scraper (..)
,   Selector (..)

,   SelectNode (..)
) where

import Control.Applicative
import Data.List

import qualified Data.Text as T
import qualified Text.HTML.TagSoup as TagSoup
import qualified Text.StringLike as TagSoup


--------------------------------------------------------------------------------
-- Selector definitions.

class Selector s str | s -> str where
    -- | Find all subsequences of a list of tags that are selected by the given
    -- selector.
    select :: TagSoup.StringLike str
           => s -> [TagSoup.Tag str] -> [[TagSoup.Tag str]]

    -- | The `@:` operator refines a selector by providing a list of attributes
    -- that must be satisfied.
    (@:) :: s -> [TagSoup.Attribute str] -> (forall a. Selector a str => a)

data SelectNode str = SelectNode str [TagSoup.Attribute str]
    deriving (Show)

instance Selector (SelectNode str) str where
    select (SelectNode node attributes) tags = concatMap extractTagBlock nodes
        where nodes = filter (checkTag node attributes) $ tails tags

    (SelectNode n a) @: a' = SelectNode n (a ++ a')

instance Selector [SelectNode str] str where
    select selectNodes tags = head $ reverse $ results ++ [[]]
        where results = [concatMap (select s) ts | s  <- selectNodes
                                                 | ts <- [tags] : results]

    selectNodes @: a' = mapLast (@: a') selectNodes
        where mapLast f (x:[]) = [f x]
              mapLast f (x:xs) = x : mapLast f xs
              mapLast f []     = []

instance Selector T.Text T.Text where
    select node = select (SelectNode node [])
    n @: a' = SelectNode n a'

-- | Given a tag name and a list of attribute predicates return a function that
-- returns true if a given tag matches the supplied name and predicates.
checkTag :: TagSoup.StringLike str
          => str -> [TagSoup.Attribute str] -> [TagSoup.Tag str] -> Bool
checkTag name preds (TagSoup.TagOpen str attrs:_)
    =  name == str && and [or [p == attr | attr <- attrs] | p <- preds]
checkTag _ _ _ = False

-- | Given a list of tags, return the prefix that of the tags up to the closing
-- tag that corresponds to the initial tag.
extractTagBlock :: TagSoup.StringLike str
                => [TagSoup.Tag str] -> [[TagSoup.Tag str]]
extractTagBlock [] = []
extractTagBlock (openTag : tags)
    | not $ TagSoup.isTagOpen openTag = []
    | otherwise                       = map (openTag :)
                                      $ splitBlock (getTagName openTag) 0 tags

splitBlock _    _       []                          = []
splitBlock name depth  (tag : tags)
    | depth == 0 && TagSoup.isTagCloseName name tag = [[tag]]
    | TagSoup.isTagCloseName name tag = tag_ $ splitBlock name (depth - 1) tags
    | TagSoup.isTagOpenName name tag  = tag_ $ splitBlock name (depth + 1) tags
    | otherwise                       = tag_ $ splitBlock name depth tags
    where tag_ = map (tag :)

getTagName :: TagSoup.StringLike str => TagSoup.Tag str -> str
getTagName (TagSoup.TagOpen name _) = name
getTagName (TagSoup.TagClose name)  = name
getTagName _                        = undefined

--------------------------------------------------------------------------------
-- Scraper definitions.

newtype Scraper str a = MkScraper {scrape :: [TagSoup.Tag str] -> Maybe a}

instance Functor (Scraper str) where
    fmap f (MkScraper a) = MkScraper $ fmap (fmap f) a

instance Applicative (Scraper str) where
    pure = MkScraper . const . Just
    (MkScraper f) <*> (MkScraper a) = MkScraper applied
        where applied tags | (Just aVal) <- a tags = ($ aVal) <$> f tags
                           | otherwise             = Nothing

instance Monad (Scraper str) where
    return = pure
    (MkScraper a) >>= f = MkScraper combined
        where combined tags | (Just aVal) <- a tags = let (MkScraper b) = f aVal
                                                      in  b tags
                            | otherwise             = Nothing
-- scrapeURL :: TagSoup.StringLike str => URL -> Scraper str a -> Maybe a
-- scrapeURL = error "TODO"

-- recurse :: Selector -> Scraper a -> Scraper a
-- recurse = error "TODO"
--
-- recurses :: Selector -> Scraper a -> Scraper [a]
-- recurses = error "TODO"
--
-- innerText :: Selector -> Scraper T.Text
-- innerText = error "TODO"
--
-- innerTexts :: Selector -> Scraper [T.Text]
-- innerTexts = error "TODO"
--
-- attribute :: Selector -> Scraper T.Text
-- attribute = error "TODO"
--
-- attributes :: Selector -> Scraper [T.Text]
-- attributes = error "TODO"
