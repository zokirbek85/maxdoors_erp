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
        "cascadeDelete": false,
        "collectionId": "pbc_631030571",
        "hidden": false,
        "id": "relation1831371789",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "payment",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "relation4113142680",
        "max": 0,
        "min": 0,
        "name": "order",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": true,
        "system": false,
        "type": "text"
      },
      {
        "hidden": false,
        "id": "number3301760891",
        "max": null,
        "min": null,
        "name": "amount_in_payment_currency",
        "onlyInt": false,
        "presentable": false,
        "required": true,
        "system": false,
        "type": "number"
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
    "id": "pbc_2618560242",
    "indexes": [
      "CREATE INDEX IF NOT EXISTS `idx_payapps_payment` ON `payment_applications` (`payment`)",
      "CREATE INDEX IF NOT EXISTS `idx_payapps_order` ON `payment_applications` (`order`)"
    ],
    "listRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\" || @request.auth.record.role = \"owner\")",
    "name": "payment_applications",
    "system": false,
    "type": "base",
    "updateRule": null,
    "viewRule": "@request.auth.id != \"\" && (@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\" || @request.auth.record.role = \"owner\")"
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2618560242");

  return app.delete(collection);
})
