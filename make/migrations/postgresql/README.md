由于 harbor-core 使用的 github.com/golang-migrate/migrat 没法去适配 gaussdb 的驱动，所以需要手动执行数据库初始化。
```shell
chmod +x run_schema_upgrade.sh && ./run_schema_upgrade.sh
```