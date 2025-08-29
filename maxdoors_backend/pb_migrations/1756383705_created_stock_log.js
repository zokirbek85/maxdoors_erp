/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = new Collection({
    "createRule": null,
    "deleteRule": null,
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
        "hidden": false,
        "id": "date3280375435",
        "max": "",
        "min": "",
        "name": "ts",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "date"
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
        "id": "number1192668439",
        "max": null,
        "min": null,
        "name": "delta_ok",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "number1427406106",
        "max": null,
        "min": null,
        "name": "delta_defect",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "hidden": false,
        "id": "select1001949196",
        "maxSelect": 1,
        "name": "reason",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "select",
        "values": [
          "purchase",
          "return_in",
          "order_pack",
          "order_cancel",
          "defect_in",
          "defect_out"
        ]
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text565658025",
        "max": 0,
        "min": 0,
        "name": "ref_id",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
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
    "id": "pbc_2642033611",
    "indexes": [
      "CREATE INDEX IF NOT EXISTS `idx_stocklog_product` ON `stock_log` (`product`)",
      "CREATE INDEX IF NOT EXISTS `idx_stocklog_ts` ON `stock_log` (`ts`)"
    ],
    "listRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"owner\")",
    "name": "stock_log",
    "system": false,
    "type": "base",
    "updateRule": null,
    "viewRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"owner\")"
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2642033611");

  return app.delete(collection);
})
