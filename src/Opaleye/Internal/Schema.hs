{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Opaleye.Internal.Schema where

import           Opaleye.Internal.Column
import           Opaleye.Internal.Table as IT
import           Opaleye.Internal.TableMaker as TM
import           Opaleye.Internal.PackMap as PM
import           Opaleye.PGTypes

import           Data.Profunctor (Profunctor, dimap, lmap)
import           Data.Profunctor.Product as PP

import qualified Data.Profunctor.Product.Default as D

class PGType a where
  data SchemaOptions a
  pgTypeName :: a -> String
  pgTypeOptions :: SchemaOptions a -> String

instance PGType PGInt8 where
  data SchemaOptions PGInt8 = NoIntOptions | Autogenerated
  pgTypeName = const "numeric"
  pgTypeOptions _ = "SERIAL"
  
instance PGType PGText where
  data SchemaOptions PGText = NoOptions
  pgTypeName = const "varchar"
  pgTypeOptions _ = "(256)"

data TableSchema = TableSchema String [UntypedColumn]

newtype UntypedColumn = UntypedColumn { unUntypedColumn :: forall a. TM.TableColumn a }

discardSchema :: IT.Table a b -> (String, IT.TableProperties a b)
discardSchema (IT.TableWithSchema _ s p) = (s, p)
discardSchema (IT.Table s p) = (s, p)

tableSchema :: forall read write.
  (D.Default SchemaMaker read write) =>
  IT.Table write read -> TableSchema
tableSchema (discardSchema -> (tableName, (IT.TableProperties _ (View tableColumns)))) =
  TableSchema tableName columns
  where
  s :: SchemaMaker read write
  s = D.def
  SchemaMaker (PM.PackMap pm) = s
  extractor d = ([d], ())
  (columns, ()) = pm extractor tableColumns

columnSchemaMaker :: SchemaMaker (TM.TableColumn any) b
columnSchemaMaker = SchemaMaker (PM.PackMap (\f (TM.TableColumn x y z) -> f (UntypedColumn (TM.TableColumn x y z))))

instance D.Default SchemaMaker (TM.TableColumn a) (Column a) where
  def = columnSchemaMaker

instance D.Default SchemaMaker (TM.TableColumn a) (TM.TableColumn a) where
  def = columnSchemaMaker

instance D.Default SchemaMaker (TM.TableColumn a) (Maybe (Column a)) where
  def = columnSchemaMaker

newtype SchemaMaker read dummy =
  SchemaMaker (PM.PackMap UntypedColumn () read ())

instance Functor (SchemaMaker a) where
  fmap _ (SchemaMaker g) = SchemaMaker (g)

instance Applicative (SchemaMaker a) where
  pure x = SchemaMaker (fmap (const ()) (pure x))
  SchemaMaker fx <*> SchemaMaker x = SchemaMaker $
    pure (const id) <*> fx <*> x

instance Profunctor SchemaMaker where
  dimap f _ (SchemaMaker q) = SchemaMaker (lmap f q)

instance ProductProfunctor SchemaMaker where
  empty = PP.defaultEmpty
  (***!) = PP.defaultProfunctorProduct
