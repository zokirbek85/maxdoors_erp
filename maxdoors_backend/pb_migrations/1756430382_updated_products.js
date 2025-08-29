/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_4092854851")

  // update collection data
  unmarshal({
    "indexes": [
      "CREATE UNIQUE INDEX IF NOT EXISTS `uq_products_name` ON `products` (`name`)",
      "CREATE UNIQUE INDEX IF NOT EXISTS `uq_products_barcode` ON `products` (`barcode`)",
      "CREATE INDEX IF NOT EXISTS `idx_products_category` ON `products` (`category`)",
      "CREATE INDEX IF NOT EXISTS `idx_products_active` ON `products` (`is_active`)",
      "CREATE INDEX `idx_bQ9rV7WAtX` ON `products` (`supplier`)"
    ]
  }, collection)

  // add field
  collection.fields.addAt(1, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_3355664324",
    "hidden": false,
    "id": "relation2603248766",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "supplier",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // update field
  collection.fields.addAt(2, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_3292755704",
    "hidden": false,
    "id": "relation105650625",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "category",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "relation"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_4092854851")

  // update collection data
  unmarshal({
    "indexes": [
      "CREATE UNIQUE INDEX IF NOT EXISTS `uq_products_name` ON `products` (`name`)",
      "CREATE UNIQUE INDEX IF NOT EXISTS `uq_products_barcode` ON `products` (`barcode`)",
      "CREATE INDEX IF NOT EXISTS `idx_products_category` ON `products` (`category`)",
      "CREATE INDEX IF NOT EXISTS `idx_products_active` ON `products` (`is_active`)"
    ]
  }, collection)

  // remove field
  collection.fields.removeById("relation2603248766")

  // update field
  collection.fields.addAt(2, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_3292755704",
    "hidden": false,
    "id": "relation105650625",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "category",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  return app.save(collection)
})
