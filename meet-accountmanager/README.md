# accountmanager


## Database setup
```sql
CREATE DATABASE accountmanager CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
CREATE USER 'accountmanager'@'localhost' IDENTIFIED BY 'secret';
GRANT CREATE, ALTER, INDEX, SELECT, UPDATE, INSERT, DELETE, REFERENCES ON accountmanager TO 'accountmanager'@'localhost';
```

