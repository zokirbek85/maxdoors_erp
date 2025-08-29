/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = new Collection({
    "createRule": "@request.auth.record.role = \"admin\" || @request.auth.record.role = \"manager\"\n",
    "deleteRule": "@request.auth.record.role = \"admin\"",
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
        "cascadeDelete": false,
        "collectionId": "_pb_users_auth_",
        "hidden": false,
        "id": "relation4196672953",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "manager",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },
      {
        "cascadeDelete": false,
        "collectionId": "pbc_859047449",
        "hidden": false,
        "id": "relation258142582",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "region",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },
      {
        "cascadeDelete": false,
        "collectionId": "pbc_3355664324",
        "hidden": false,
        "id": "relation2603248766",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "supplier",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "relation"
      },
      {
        "hidden": false,
        "id": "select308040339",
        "maxSelect": 1,
        "name": "discount_type",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "select",
        "values": [
          "none",
          "percent"
        ]
      },
      {
        "hidden": false,
        "id": "number912097443",
        "max": null,
        "min": null,
        "name": "discount_value",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text2140143823",
        "max": 0,
        "min": 0,
        "name": "none",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "hidden": false,
        "id": "select2063623452",
        "maxSelect": 1,
        "name": "status",
        "presentable": false,
        "required": true,
        "system": false,
        "type": "select",
        "values": [
          "created",
          "edit_requested",
          "packed",
          "shipped"
        ]
      },
      {
        "hidden": false,
        "id": "number2488022847",
        "max": null,
        "min": null,
        "name": "daily_seq",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text2327659904",
        "max": 0,
        "min": 0,
        "name": "human_id",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "hidden": false,
        "id": "bool2636136329",
        "name": "editable",
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
    "id": "pbc_3527180448",
    "indexes": [
      "CREATE INDEX IF NOT EXISTS `idx_orders_dealer` ON `orders` (`dealer`)",
      "CREATE INDEX IF NOT EXISTS `idx_orders_status` ON `orders` (`status`)",
      "CREATE INDEX IF NOT EXISTS `idx_orders_human` ON `orders` (`human_id`)"
    ],
    "listRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"manager\" ||\n  @request.auth.record.role = \"warehouseman\" ||\n  @request.auth.record.role = \"owner\"\n)",
    "name": "orders",
    "system": false,
    "type": "base",
    "updateRule": "@request.auth.record.role = \"admin\" ||\n(@request.auth.record.role = \"manager\" && editable = true) ||\n(@request.auth.record.role = \"warehouseman\" && (status = \"created\" || status = \"packed\"))\n",
    "viewRule": "@request.auth.id != \"\" && (\n  @request.auth.record.role = \"admin\" ||\n  @request.auth.record.role = \"accountant\" ||\n  @request.auth.record.role = \"manager\" ||\n  @request.auth.record.role = \"warehouseman\" ||\n  @request.auth.record.role = \"owner\"\n)"
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3527180448");

  return app.delete(collection);
})
