/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = new Collection({
    "createRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "deleteRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "fields": [
      {
        "autogeneratePattern": "[a-z0-9]{15}",
        "hidden": false,
        "id": "text3208210256",
        "max": 15,
        "min": 15,
        "name": "id",
        "pattern": "^[a-z0-9]+$",
        "presentable": false,
        "primaryKey": true,
        "required": true,
        "system": true,
        "type": "text"
      },
      {
        "cascadeDelete": false,
        "collectionId": "pbc_3714752023",
        "hidden": false,
        "id": "relation723623280",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "entry",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },
      {
        "cascadeDelete": false,
        "collectionId": "pbc_4092854851",
        "hidden": false,
        "id": "relation3544843437",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "product",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },
      {
        "hidden": false,
        "id": "number3371740703",
        "max": null,
        "min": null,
        "name": "qty",
        "onlyInt": false,
        "presentable": false,
        "required": true,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number3402113753",
        "max": null,
        "min": null,
        "name": "price",
        "onlyInt": false,
        "presentable": false,
        "required": true,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "bool1792390488",
        "name": "is_defect",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "bool"
      },
      {
        "hidden": false,
        "id": "autodate2990389176",
        "name": "created",
        "onCreate": true,
        "onUpdate": false,
        "presentable": false,
        "system": false,
        "type": "autodate"
      },
      {
        "hidden": false,
        "id": "autodate3332085495",
        "name": "updated",
        "onCreate": true,
        "onUpdate": true,
        "presentable": false,
        "system": false,
        "type": "autodate"
      }
    ],
    "id": "pbc_654718158",
    "indexes": [
      "CREATE INDEX IF NOT EXISTS `idx_sei_entry` ON `stock_entry_items` (`entry`)",
      "CREATE INDEX IF NOT EXISTS `idx_sei_product` ON `stock_entry_items` (`product`)"
    ],
    "listRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\" || @request.auth.record.role = \"owner\")",
    "name": "stock_entry_items",
    "system": false,
    "type": "base",
    "updateRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "viewRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\" || @request.auth.record.role = \"owner\")"
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_654718158");

  return app.delete(collection);
})
