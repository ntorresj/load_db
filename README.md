# README #

Download & Import Database from S3.

### How to use? ###

* Clone the repo `YOUR_PATH`
* `cd YOUR_PATH/load_db`
* Run `./load_db.rb tenant`

### What does? ###

* Download a DB from a specific tenant
 * If the file exists, the script ask you if you want to donwload again or load the backup donwloaded
* If you forget type the tenant the script ask you while is running
* When it connect with the server will show all the backups available, so you only have to choose one
* Create a DB using the tenant name `tenant`, you can edit database's name too
```
ie. 
$db = "{client}" -> tenant
$db = "{client}_anyText" -> tenant_anyText
$db = "anyText" -> anyText
```
 * If the DB exists will be removed

### Config ###

* `cp settings.rb.default settings.rb`
* Use the `settings.rb` to set the folder backups download and set MySQL credentials

### Example. ###

Download and create DB

```RUBY
./load_db.rb tenant
```