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
        "collectionId": "pbc_1682207476",
        "hidden": false,
        "id": "relation396572930",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "dealer",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },
      {
        "hidden": false,
        "id": "date2862495610",
        "max": "",
        "min": "",
        "name": "date",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "date"
      },
      {
        "hidden": false,
        "id": "number1982676558",
        "max": null,
        "min": null,
        "name": "amount_usd",
        "onlyInt": false,
        "presentable": false,
        "required": true,
        "system": false,
        "type": "number"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text3485334036",
        "max": 0,
        "min": 0,
        "name": "note",
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
    "id": "pbc_4153672788",
    "indexes": [
      "CREATE INDEX IF NOT EXISTS `idx_dba_date` ON `dealer_balance_adjustments` (`date`)",
      "CREATE INDEX `idx_21UdrOpP1N` ON `dealer_balance_adjustments` (`dealer`)"
    ],
    "listRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"owner\"\n)\n  ",
    "name": "dealer_balance_adjustments",
    "system": false,
    "type": "base",
    "updateRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"accountant\"",
    "viewRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"owner\"\n)\n"
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_4153672788");

  return app.delete(collection);
})
