
## 1. Como admin_sabanero, crea un rol llamado rol_admin_local.
   Se crea una nueva conexión en la DB, con esta información 
```
| Campo            | Valor            |
| ---------------- | ---------------- |
| Name             | `admin_sabanero` |
| Username         | `admin_sabanero` |
| Password         | `Sabanero123`    |
| Hostname         | `localhost`      |
| Port             | `1521`           |
| **Service name** | **`FREEPDB1`**   |
```

se valida el contenedor correcto 
**QUERY**
```sql
SELECT USER, SYS_CONTEXT('USERENV','CON_NAME') AS contenedor FROM dual;
```
**RESULT**
```
| USER             | CONTENEDOR       |
| ---------------- | ---------------- |
| ADMIN_SABANERO   | FREEPDB1         |
```

Se crea el rol
```sql
CREATE ROLE rol_admin_local;
```

para validar creación

```sql
SELECT granted_role, admin_option
FROM user_role_privs
WHERE granted_role = 'ROL_ADMIN_LOCAL';
```

resultado 
```
| GRANTED ROLE     | ADMIN OPTIN      |
| ---------------- | ---------------- |
| ROL_ADMIN_LOCAL  | YES              |
```

## 2 . Otorga los privilegios CREATE TABLE, CREATE VIEW y CREATE USER al rol_admin_local.

```sql
GRANT CREATE TABLE, CREATE VIEW, CREATE USER TO rol_admin_local;
```
validación de la query
```sql
SELECT role, privilege, admin_option
FROM role_sys_privs
WHERE role = 'ROL_ADMIN_LOCAL'
ORDER BY privilege;
```

resultado 
```
| ROLE             | PRIVILEGE      | ADMIN OPTIN     |
| -----------------| ---------------|-----------------|
| ROL_ADMIN_LOCAL  | CREATE TABLE   | NO              |
| ROL_ADMIN_LOCAL  | CREATE USER    | NO              |
| ROL_ADMIN_LOCAL  | CREATE VIEW    | NO              |
```

`ADMIN_OPTION = NO` indica que el rol tiene los privilegios, pero quien lo reciba **no podrá otorgarlos individualmente** a otros.

## 3.  Crea una usuaria llamada admin_teusaquillo y asígnale el rol rol_admin_local.
Ejecución de query
```sql
CREATE USER admin_teusaquillo IDENTIFIED BY Teusa123
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;

GRANT CREATE SESSION TO admin_teusaquillo;
GRANT rol_admin_local TO admin_teusaquillo;
```
se valida pero desde el usuario system no desde admin_sabanero

```sql
SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee = 'ADMIN_TEUSAQUILLO';
```
resultado
```
| GRANTEE           | GRANTED_ROLE    |  ADMIN_OPTION   | DEFAULT_ROLE   |
| ------------------| ----------------|-----------------|----------------|
| ADMIN_TEUSAQUILLO | ROL_ADMIN_LOCAL | NO              | YES            |
```

## 4. Inicia sesión como admin_teusaquillo y comprueba que puede crear una tabla y un nuevo usuario.

Para este punto se crea en SQL Developer la conexión `admin_teusaquillo`:
query validación
```sql
SELECT USER, SYS_CONTEXT('USERENV','CON_NAME') AS contenedor FROM dual;
```

| USER              | CONTENEDOR |
| ----------------- | ---------- |
| ADMIN_TEUSAQUILLO | FREEPDB1   |
```sql
SELECT * FROM session_roles;
SELECT * FROM session_privs ORDER BY privilege;
```
validar privilegios 
```
| PRIVILEGE      | 
| ---------------|
| CREATE SESSION | 
| CREATE USER    |
| CREATE VIEW    |

```
Creacion de tabla
```sql
CREATE TABLE prueba_teusaquillo (
  id     NUMBER PRIMARY KEY,
  nombre VARCHAR2(50)
);

INSERT INTO prueba_teusaquillo VALUES (1, 'Prueba punto 4');
COMMIT;

SELECT * FROM prueba_teusaquillo;
```
validación
```
| ID             | NOMBRE           |
| -------------- | ---------------- |
| 1              | Prueba punto 4   |
```

## 5. Como admin_sabanero, revoca el rol rol_admin_local de admin_teusaquillo.
Ejecución de query desde la conexión `admin_sabanero`
```sql
REVOKE rol_admin_local FROM admin_teusaquillo;
```
se valida desde el usuario system
```sql
SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee = 'ADMIN_TEUSAQUILLO';
```
resultado
```
| GRANTEE           | GRANTED_ROLE    |  ADMIN_OPTION   | DEFAULT_ROLE   |
| ------------------| ----------------|-----------------|----------------|
|                   |                 |                 |                |
```
La consulta no devuelve filas, lo que confirma que admin_teusaquillo ya no tiene el rol.

Se desconecta y se vuelve a conectar la conexión `admin_teusaquillo`, ya que los roles se cargan al iniciar sesión.

validar privilegios
```sql
SELECT * FROM session_privs ORDER BY privilege;
```
```
| PRIVILEGE      |
| ---------------|
| CREATE SESSION |
```
Se intenta crear una tabla
```sql
CREATE TABLE prueba_sin_rol (id NUMBER);
```
resultado
```
ORA-01031: insufficient privileges
```
Al no tener el rol, admin_teusaquillo solo conserva el privilegio CREATE SESSION, que se le otorgó directamente, por lo que puede conectarse pero ya no puede crear tablas.

## 6. Ahora, concede el rol rol_admin_local a admin_teusaquillo WITH ADMIN OPTION.
Ejecución de query desde la conexión `admin_sabanero`
```sql
GRANT rol_admin_local TO admin_teusaquillo WITH ADMIN OPTION;
```
se valida desde el usuario system
```sql
SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee = 'ADMIN_TEUSAQUILLO';
```
resultado
```
| GRANTEE           | GRANTED_ROLE    |  ADMIN_OPTION   | DEFAULT_ROLE   |
| ------------------| ----------------|-----------------|----------------|
| ADMIN_TEUSAQUILLO | ROL_ADMIN_LOCAL | YES             | YES            |
```
A diferencia del punto 3, ahora `ADMIN_OPTION = YES`, lo que indica que admin_teusaquillo no solo puede usar el rol, sino también **otorgarlo y revocarlo a otros usuarios**.

## 7. Inicia sesión como admin_teusaquillo y crea un nuevo usuario admin_usaquen.
Se desconecta y se vuelve a conectar la conexión `admin_teusaquillo` para que tome el rol.

query validación
```sql
SELECT * FROM session_roles;
```
```
| ROLE            |
| ----------------|
| ROL_ADMIN_LOCAL |
```
Creación del usuario
```sql
CREATE USER admin_usaquen IDENTIFIED BY Usaquen123
  DEFAULT TABLESPACE users QUOTA 10M ON users;
```
resultado
```
User ADMIN_USAQUEN created.
```
admin_teusaquillo puede crear el usuario gracias al privilegio CREATE USER que recibe a través del rol.

Se intenta otorgar el permiso de conexión al nuevo usuario
```sql
GRANT CREATE SESSION TO admin_usaquen;
```
resultado
```
ORA-01031: insufficient privileges
```
admin_teusaquillo no puede otorgar CREATE SESSION, ya que ese privilegio no hace parte del rol y ella no lo tiene con opción de administración. Por eso se otorga desde la conexión `admin_sabanero`
```sql
GRANT CREATE SESSION TO admin_usaquen;
```
El WITH ADMIN OPTION permite delegar **el rol**, pero no los privilegios que se tienen por fuera de él.

## 8. Como admin_teusaquillo, concede el rol rol_admin_local a admin_usaquen.
Ejecución de query desde la conexión `admin_teusaquillo`
```sql
GRANT rol_admin_local TO admin_usaquen;
```
se valida desde el usuario system
```sql
SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee IN ('ADMIN_TEUSAQUILLO', 'ADMIN_USAQUEN')
ORDER BY grantee;
```
resultado
```
| GRANTEE           | GRANTED_ROLE    |  ADMIN_OPTION   | DEFAULT_ROLE   |
| ------------------| ----------------|-----------------|----------------|
| ADMIN_TEUSAQUILLO | ROL_ADMIN_LOCAL | YES             | YES            |
| ADMIN_USAQUEN     | ROL_ADMIN_LOCAL | NO              | YES            |
```
admin_teusaquillo pudo otorgar el rol gracias al WITH ADMIN OPTION del punto 6. admin_usaquen lo recibe con `ADMIN_OPTION = NO`, es decir, puede usarlo pero no otorgarlo a otros.

## 9. Inicia sesión como admin_usaquen y verifica que también puede crear tablas y usuarios.
Para este punto se crea en DBeaver la conexión `admin_usaquen`:
```
| Campo            | Valor            |
| ---------------- | ---------------- |
| Username         | `admin_usaquen`  |
| Password         | `Usaquen123`     |
| Hostname         | `localhost`      |
| Port             | `1521`           |
| **Service name** | **`FREEPDB1`**   |
```
query validación
```sql
SELECT USER, SYS_CONTEXT('USERENV','CON_NAME') AS contenedor FROM dual;
```
```
| USER             | CONTENEDOR       |
| ---------------- | ---------------- |
| ADMIN_USAQUEN    | FREEPDB1         |
```
validar privilegios
```sql
SELECT * FROM session_roles;
SELECT * FROM session_privs ORDER BY privilege;
```
```
| PRIVILEGE      |
| ---------------|
| CREATE SESSION |
| CREATE TABLE   |
| CREATE USER    |
| CREATE VIEW    |
```
Creación de tabla
```sql
CREATE TABLE prueba_usaquen (
  id     NUMBER PRIMARY KEY,
  nombre VARCHAR2(50)
);

INSERT INTO prueba_usaquen VALUES (1, 'Prueba punto 9');
COMMIT;

SELECT * FROM prueba_usaquen;
```
validación
```
| ID             | NOMBRE           |
| -------------- | ---------------- |
| 1              | Prueba punto 9   |
```
Creación de usuario
```sql
CREATE USER usuario_prueba_usaquen IDENTIFIED BY Prueba123;
```
resultado
```
User USUARIO_PRUEBA_USAQUEN created.
```
admin_usaquen puede crear tablas y usuarios con los privilegios del rol que le otorgó admin_teusaquillo.

## 10. Como admin_sabanero, revoca el privilegio CREATE USER del rol rol_admin_local.
Ejecución de query desde la conexión `admin_sabanero`
```sql
REVOKE CREATE USER FROM rol_admin_local;
```
validación de la query
```sql
SELECT role, privilege, admin_option
FROM role_sys_privs
WHERE role = 'ROL_ADMIN_LOCAL'
ORDER BY privilege;
```
resultado
```
| ROLE             | PRIVILEGE      | ADMIN OPTION    |
| -----------------| ---------------|-----------------|
| ROL_ADMIN_LOCAL  | CREATE TABLE   | NO              |
| ROL_ADMIN_LOCAL  | CREATE VIEW    | NO              |
```
El rol queda únicamente con CREATE TABLE y CREATE VIEW.

## 11. Comprueba si admin_teusaquillo y admin_usaquen todavía pueden crear usuarios. Documenta tus hallazgos y explica el comportamiento.
Se desconectan y se vuelven a conectar las conexiones `admin_teusaquillo` y `admin_usaquen`.

Desde la conexión `admin_teusaquillo`
```sql
SELECT * FROM session_privs ORDER BY privilege;
```
```
| PRIVILEGE      |
| ---------------|
| CREATE SESSION |
| CREATE TABLE   |
| CREATE VIEW    |
```
```sql
CREATE USER otro_usuario1 IDENTIFIED BY Otro123;
```
resultado
```
ORA-01031: insufficient privileges
```
Desde la conexión `admin_usaquen`
```sql
SELECT * FROM session_privs ORDER BY privilege;
```
```
| PRIVILEGE      |
| ---------------|
| CREATE SESSION |
| CREATE TABLE   |
| CREATE VIEW    |
```
```sql
CREATE USER otro_usuario2 IDENTIFIED BY Otro123;
```
resultado
```
ORA-01031: insufficient privileges
```
**Hallazgos:** ninguno de los dos usuarios puede crear usuarios. Ambos recibían el privilegio CREATE USER a través del rol rol_admin_local y no de forma directa, por lo que al revocarlo del rol se pierde automáticamente para todos los usuarios que lo tienen, sin necesidad de modificar sus cuentas una por una. Esto ocurre incluso con admin_teusaquillo, que tiene el rol WITH ADMIN OPTION: esa opción le permite administrar el rol, pero no le garantiza los privilegios que el dueño del rol decida quitarle. Los objetos creados antes del cambio se conservan, como los usuarios admin_usaquen y usuario_prueba_usaquen.

## 12. Crea un nuevo rol llamado rol_auditor. No le concedas ningún privilegio todavía.

Se inicia sesión como `admin_sabanero` y se verifica que la conexión corresponde a `FREEPDB1`:

```sql
SELECT USER AS usuario, SYS_CONTEXT('USERENV','CON_NAME') AS contenedor
FROM dual;
```

**Resultado**

| USUARIO        |CONTENEDOR  |
| -------------- | ---------- | 
| ADMIN_SABANERO | FREEPDB1   |

Se crea el rol `rol_auditor`. En el script de ejecución se utilizó el siguiente bloque para evitar volverlo a crear si ya existía en el esquema de roles que hay disponibles para `admin_sabanero`:

```sql
DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_existe
  FROM user_role_privs
  WHERE granted_role = 'ROL_AUDITOR';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE 'CREATE ROLE rol_auditor';
  END IF;
END;
/
```

**Resultado obtenido**

```text
PL/SQL procedure successfully completed.
```

Para comprobar su creación:

```sql
SELECT granted_role, admin_option
FROM user_role_privs
WHERE granted_role = 'ROL_AUDITOR';
```

**Resultado**

| GRANTED_ROLE | ADMIN_OPTION |
| -------------| ------------ |
| ROL_AUDITOR  | YES          |

El creador del rol recibe la opción administrativa sobre este. Esto no significa que el rol tenga privilegios de sistema o de objeto.

Para comprobar que el rol se creó sin privilegios, desde `admin_sabanero` se ejecutan las siguientes consultas:

```sql
SELECT role, privilege
FROM role_sys_privs
WHERE role = 'ROL_AUDITOR';

SELECT role, owner, table_name, privilege
FROM role_tab_privs
WHERE role = 'ROL_AUDITOR';

SELECT role, granted_role
FROM role_role_privs
WHERE role = 'ROL_AUDITOR';
```

**Resultado de las tres consultas**

```text
no rows selected
```

**Conclusión:** `ROL_AUDITOR` fue creado correctamente y todavía no tiene privilegios de sistema, los privilegios sobre objetos ni otros roles asignados, cumpliendo con la condición.

## 13. Concede el rol rol_auditor a admin_teusaquillo WITH ADMIN OPTION.

Desde la conexión `admin_sabanero` se ejecuta:

```sql
GRANT rol_auditor TO admin_teusaquillo WITH ADMIN OPTION;
```

**Resultado obtenido**

```text
Grant succeeded.
```

Para validar la asignación, se inicia sesión como `admin_teusaquillo` y se consulta:

```sql
SELECT granted_role, admin_option, default_role
FROM user_role_privs
WHERE granted_role = 'ROL_AUDITOR';
```

**Resultado**

| GRANTED_ROLE | ADMIN_OPTION | DEFAULT_ROLE |
| ------------ | ------------ | ------------ |
| ROL_AUDITOR  | YES          | YES          |

`ADMIN_OPTION = YES` confirma que `admin_teusaquillo` recibió el rol con permiso para concedérselo a otros usuarios, esto no le agrega privilegios al contenido del rol, que sigue vacío.

## 14. Como admin_teusaquillo, concede al rol rol_auditor a admin_usaquen.

Desde la conexión `admin_teusaquillo`, se concede el rol al segundo usuario:

```sql
GRANT rol_auditor TO admin_usaquen;
```

**Resultado obtenido**

```text
Grant succeeded.
```

Se inicia sesión como `admin_usaquen` para confirmar que recibió el rol:

```sql
SELECT USER AS usuario, SYS_CONTEXT('USERENV','CON_NAME') AS contenedor
FROM dual;

SELECT granted_role, admin_option, default_role
FROM user_role_privs
WHERE granted_role = 'ROL_AUDITOR';
```

**Resultados**

| USUARIO       | CONTENEDOR |
| ------------- | ---------- |
| ADMIN_USAQUEN | FREEPDB1   |

| GRANTED_ROLE | ADMIN_OPTION | DEFAULT_ROLE |
| ------------ | ------------ | ------------ |
| ROL_AUDITOR  | NO           | YES          |

Para confirmar el estado final de las asignaciones, desde `SYS` en `FREEPDB1` se ejecutó:

```sql
SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee IN ('ADMIN_TEUSAQUILLO','ADMIN_USAQUEN')
  AND granted_role IN ('ROL_ADMIN_LOCAL','ROL_AUDITOR')
ORDER BY granted_role, grantee;
```

**Resultado obtenido**

| GRANTEE           | GRANTED_ROLE    | ADMIN_OPTION | DEFAULT_ROLE |
| ----------------  | --------------- | -----------  | ------------ |
| ADMIN_TEUSAQUILLO | ROL_ADMIN_LOCAL | YES          | YES          |
| ADMIN_USAQUEN     | ROL_ADMIN_LOCAL | NO           | YES          |
| ADMIN_TEUSAQUILLO | ROL_AUDITOR     | YES          | YES          | 
| ADMIN_USAQUEN     | ROL_AUDITOR     | NO           | YES          |

**Conclusión:** `admin_teusaquillo` pudo otorgar `ROL_AUDITOR` porque lo recibió con `WITH ADMIN OPTION`. Por su parte, `admin_usaquen` recibió el rol sin esa opción, por lo que puede tenerlo asignado pero no delegarlo a otros usuarios, como `ROL_AUDITOR` continúa sin privilegios, su asignación no concede nuevos permisos para crear tablas, vistas ni usuarios.
