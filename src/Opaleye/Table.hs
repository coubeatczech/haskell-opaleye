{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

module Opaleye.Table (module Opaleye.Table,
                      View,
                      Writer,
                      Table(Table),
                      TableProperties) where

import           Opaleye.Internal.Column (Column)
import qualified Opaleye.Internal.QueryArr as Q
import qualified Opaleye.Internal.Table as T
import           Opaleye.Internal.Table (View(View), Table, Writer,
                                         TableProperties)
import qualified Opaleye.Internal.TableMaker as TM
import qualified Opaleye.Internal.Tag as Tag
import qualified Opaleye.PGTypes as PG

import qualified Data.Profunctor.Product.Default as D

-- | Example type specialization:
--
-- @
-- queryTable :: Table w (Column a, Column b) -> Query (Column a, Column b)
-- @
--
-- Assuming the @makeAdaptorAndInstance@ splice has been run for the
-- product type @Foo@:
--
-- @
-- queryTable :: Table w (Foo (Column a) (Column b) (Column c)) -> Query (Foo (Column a) (Column b) (Column c))
-- @
queryTable :: D.Default TM.ColumnMaker read read' =>
              Table write read -> Q.Query read'
queryTable = queryTableExplicit D.def

queryTableExplicit :: TM.ColumnMaker read read' ->
                     Table write read -> Q.Query read'
queryTableExplicit cm table = Q.simpleQueryArr f where
  f ((), t0) = (retwires, primQ, Tag.next t0) where
    (retwires, primQ) = T.queryTable cm table t0

required :: forall a. (PGType a) => String -> Options a -> TableProperties (Column a) (TM.TableColumn a)
required columnName options = T.TableProperties
  (T.required columnName)
  (View (TM.TableColumn (TM.ColumnDescription columnName type_ options')))
  where
  type_ = pgTypeName (undefined :: a)
  options' = pgTypeOptions options

optional :: forall a. (PGType a) => String -> Options a -> TableProperties (Maybe (Column a)) (TM.TableColumn a)
optional columnName options = T.TableProperties
  (T.optional columnName)
  (View (TM.TableColumn (TM.ColumnDescription columnName type_ options')))
  where
  type_ = pgTypeName (undefined :: a)
  options' = pgTypeOptions options

class PGType a where
  data Options a
  pgTypeName :: a -> String
  pgTypeOptions :: Options a -> String
instance PGType PG.PGInt8 where
  data Options PG.PGInt8 = NoIntOptions | Autogenerated
  pgTypeName _ = "int"
  pgTypeOptions _ = ""
instance PGType PG.PGText where
  data Options PG.PGText = NoTextOptions
  pgTypeName _ = "text"
  pgTypeOptions _ = ""
instance PGType PG.PGNumeric where
  data Options PG.PGNumeric = NumericOptions {
    precision :: Int ,
    scale :: Int }
  pgTypeName _ = "numeric"
  pgTypeOptions (NumericOptions precision' scale') = "(" ++ show precision' ++ "," ++ show scale' ++ ")"
