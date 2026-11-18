# Informe — Workshop #4: Usuarios, privilegios y roles

**Curso:** Administración de Bases de Datos, ITM\
**Actividad:** Workshop #4, caso 14 "La Sabana"\
**Script:** `workshop4_la_sabana.sql`, se ejecuta con `sqlplus /nolog @workshop4_la_sabana.sql` y pide la contraseña de SYSTEM\
**Entorno:** Oracle 23ai Free y SQL*Plus 23. El mismo script corre sin cambios en 21c XE y 18c XE (la familia de 19c).

Los extractos son salida literal de SQL*Plus de una ejecución completa del script, que terminó con código 0. Las únicas líneas omitidas son las `Help: https://docs.oracle.com/error-help/...` que 23ai agrega a cada error.

## 1. Marco conceptual

Oracle distingue dos tipos de privilegio [1]. Un **privilegio de sistema** permite una acción en toda la base de datos, como `CREATE USER` o `CREATE TABLE`. Un **privilegio de objeto** permite una acción sobre un objeto concreto, como `SELECT` sobre la tabla `admin_teusaquillo.barrios_teusaquillo`.

Un **rol** es un conjunto de privilegios con nombre. Los privilegios se otorgan al rol y el rol a los usuarios, así que un cambio en el rol alcanza a todos sus usuarios a la vez. Por eso Oracle recomienda otorgar los privilegios a roles y no a usuarios específicos [3].

El taller gira alrededor de la **delegación**: la capacidad de quien recibe un privilegio de pasarlo a otros. Oracle tiene dos cláusulas para eso, con reglas distintas:

| | `WITH ADMIN OPTION` | `WITH GRANT OPTION` |
| --- | --- | --- |
| Se aplica a | Privilegios de sistema y roles | Privilegios de objeto, otorgados a usuarios o a `PUBLIC` (no a roles) [1] |
| Qué puede hacer quien lo recibe | Otorgarlo a otros, revocarlo a cualquier usuario o rol y eliminarlo [1] | Otorgarlo a otros [1] |
| ¿El diccionario registra quién lo otorgó? | No: `DBA_ROLE_PRIVS` y `DBA_SYS_PRIVS` no tienen columna de otorgante | Sí: columna `GRANTOR` de `DBA_TAB_PRIVS` |
| Si se le revoca a quien lo recibió | Lo que esa persona otorgó **se conserva**: no hay cascada [4] | Lo que esa persona otorgó **se revoca en cascada** [2] |
| Si se usa con el tipo de privilegio equivocado | `ORA-00993` | `ORA-01939` |

La cuarta fila es la que más importa. Cuando Oracle no registra quién otorgó algo, tampoco puede deshacer lo que esa persona repartió. La documentación afirma la ausencia de cascada para los privilegios de sistema de DDL [4]. Para los roles lo comprobamos en la tarea 16.

**Cuándo tiene efecto un cambio** [3]: los grants y revokes de *privilegios*, también los hechos a un rol, se aplican de inmediato, incluso en sesiones abiertas. Los grants y revokes de *roles* se aplican solo en una sesión nueva o después de un `SET ROLE`. Por eso el script verifica cada revocación de rol con un `CONNECT` nuevo.

## 2. Preparación

El script se conecta siempre a la PDB (`FREEPDB1`), porque en la raíz del CDB `CREATE USER` falla con ORA-65096. Primero elimina los usuarios y roles de ejecuciones anteriores, así que se puede repetir. Después SYSTEM crea a `admin_sabanero` solo con lo que el caso exige:

- `CREATE ROLE` para las tareas 1 y 12, y `CREATE SESSION WITH ADMIN OPTION` para entrar y dar acceso a los administradores locales.
- `CREATE TABLE`, `CREATE VIEW` y `CREATE USER` `WITH ADMIN OPTION`. Sin la ADMIN OPTION no podría otorgarlos al rol (tarea 2) ni revocarlos (tarea 10). Se descartó `GRANT ANY PRIVILEGE` porque permite otorgar cualquier privilegio, no solo estos tres.

## 3. Desarrollo

### A. Tareas 1-4: delegar mediante un rol

**Pregunta:** ¿basta el rol para que `admin_teusaquillo` cree tablas y usuarios?

`admin_sabanero` crea `rol_admin_local` y lo recibe automáticamente con `ADMIN_OPTION = YES` por ser su creador. Luego otorga los tres privilegios al rol y crea a `admin_teusaquillo` con `CREATE SESSION` directo, que no forma parte del rol, y una cuota en `users` para que pueda insertar filas.

```
SQL> SELECT privilege FROM session_privs ORDER BY privilege;

PRIVILEGE
----------------
CREATE SESSION
CREATE TABLE
CREATE USER
CREATE VIEW

4 rows selected.

SQL> SELECT * FROM prueba_teusaquillo;

        ID NOMBRE
---------- ------------------------------
         1 Prueba tarea 4

SQL> CREATE USER usuario_prueba_teusaquillo IDENTIFIED BY Prueba123;

User created.
```

**Conclusión:** sí. Los tres privilegios llegan a través del rol, y el único privilegio directo es `CREATE SESSION`.

### B. Tarea 5: revocar el rol

```
SQL> REVOKE rol_admin_local FROM admin_teusaquillo;

Revoke succeeded.

SQL> CONNECT admin_teusaquillo/Teusa123@&conn
Connected.
SQL> SELECT granted_role FROM user_role_privs;

no rows selected

SQL> SELECT privilege FROM session_privs ORDER BY privilege;

PRIVILEGE
----------------
CREATE SESSION

1 row selected.
```

**Conclusión:** una sola sentencia retira los tres privilegios del rol, y el `CREATE SESSION` otorgado directamente se conserva. La verificación se hace desde una sesión nueva porque la revocación de un rol no afecta a las sesiones ya abiertas (sección 1).

### C. Tareas 6-9: `WITH ADMIN OPTION` y delegación en cadena

**Pregunta:** con la ADMIN OPTION sobre el rol, ¿qué puede delegar `admin_teusaquillo` y qué no?

```
SQL> SELECT granted_role, admin_option, default_role
  2  FROM user_role_privs;

GRANTED_ROLE     ADMIN_OPTION DEFAULT_ROLE
---------------- ------------ ------------
ROL_ADMIN_LOCAL  YES          YES

SQL> CREATE USER admin_usaquen IDENTIFIED BY Usaquen123
  2    DEFAULT TABLESPACE users QUOTA 10M ON users;

User created.

SQL> GRANT CREATE SESSION TO admin_usaquen;
GRANT CREATE SESSION TO admin_usaquen
*
ERROR at line 1:
ORA-01031: insufficient privileges

SQL> GRANT rol_admin_local TO admin_usaquen;

Grant succeeded.
```

**Hallazgo:** la ADMIN OPTION sobre un rol permite delegar *el rol*, no los demás privilegios del usuario. `admin_teusaquillo` recibió `CREATE SESSION` sin ADMIN OPTION, así que no puede pasarlo (ORA-01031). Sin ese privilegio `admin_usaquen` no podría entrar, de modo que `admin_sabanero` se lo otorga como paso de soporte. En la tarea 9, `admin_usaquen` tiene los mismos cuatro privilegios de la tarea 4 y crea `prueba_usaquen` y `usuario_prueba_usaquen` sin errores. La diferencia con quien le delegó el rol es la opción de administración:

```
GRANTED_ROLE     ADMIN_OPTION DEFAULT_ROLE
---------------- ------------ ------------
ROL_ADMIN_LOCAL  NO           YES
```

**Conclusión:** `admin_usaquen` puede *usar* el rol, pero no *delegarlo*.

### D. Tareas 10-11: revocar un privilegio del rol

**Pregunta:** si `admin_sabanero` quita `CREATE USER` del rol, ¿lo pierden también quienes recibieron el rol, incluso con ADMIN OPTION?

```
SQL> REVOKE CREATE USER FROM rol_admin_local;

Revoke succeeded.

ROLE             PRIVILEGE        ADMIN_OPTION
---------------- ---------------- ------------
ROL_ADMIN_LOCAL  CREATE TABLE     NO
ROL_ADMIN_LOCAL  CREATE VIEW      NO

SQL> CONNECT admin_teusaquillo/Teusa123@&conn
Connected.
SQL> CREATE USER otro_teusaquillo IDENTIFIED BY Otro123;
CREATE USER otro_teusaquillo IDENTIFIED BY Otro123
*
ERROR at line 1:
ORA-01031: insufficient privileges
```

`admin_usaquen` obtiene el mismo `ORA-01031` con `CREATE USER otro_usaquen`.

**Explicación:** ninguno de los dos tenía `CREATE USER` propio: lo recibían a través del rol. Al quitarlo del rol, lo pierden todos sus usuarios a la vez, sin tocar sus cuentas. Según la documentación, el cambio es inmediato incluso en sesiones abiertas [2]. La ADMIN OPTION no protege a `admin_teusaquillo`, porque controla *a quién* se otorga el rol y no *qué contiene*. Lo que ya se creó se conserva: `admin_usaquen` y los usuarios `usuario_prueba_*` siguen existiendo.

### E. Tareas 12-16: `rol_auditor` y la ausencia de cascada

**Pregunta:** si se le revoca un rol a quien lo delegó, ¿lo pierde también quien lo recibió de esa persona?

`admin_sabanero` crea `rol_auditor` sin privilegios. Las consultas a `role_sys_privs`, `role_tab_privs` y `role_role_privs` devuelven `no rows selected`. Luego otorga el rol a `admin_teusaquillo` `WITH ADMIN OPTION`, ella se lo otorga a `admin_usaquen` y `admin_sabanero` se lo revoca a ella. Así queda `DBA_ROLE_PRIVS`:

```
SQL> SELECT grantee, granted_role, admin_option, default_role
  2  FROM dba_role_privs
  3  WHERE granted_role = 'ROL_AUDITOR';

GRANTEE                    GRANTED_ROLE     ADMIN_OPTION DEFAULT_ROLE
-------------------------- ---------------- ------------ ------------
ADMIN_USAQUEN              ROL_AUDITOR      NO           YES
ADMIN_SABANERO             ROL_AUDITOR      YES          YES
```

**Resultado:** `admin_usaquen` **conserva** `rol_auditor` y lo tiene activo en su sesión (`session_roles`). `admin_teusaquillo` lo perdió.

**Explicación:** la revocación de un rol no se propaga en cascada. `DBA_ROLE_PRIVS` guarda quién tiene el rol, pero no quién se lo dio. Oracle no conoce la cadena `admin_teusaquillo → admin_usaquen`, así que no puede deshacerla. Todo lo que repartió `admin_teusaquillo` sobrevive a su revocación, y hay que buscarlo y revocarlo uno por uno.

### F. Tarea 17: `WITH ADMIN OPTION` frente a `WITH GRANT OPTION`

**Pregunta:** ¿qué pasa al usar cada cláusula con un privilegio de objeto, y en qué se diferencia la revocación?

`admin_teusaquillo` crea `barrios_teusaquillo` con dos filas e intenta delegar el `SELECT` sobre ella:

| Intento | Sentencia | Resultado |
| --- | --- | --- |
| ADMIN OPTION sobre un privilegio de objeto | `GRANT SELECT ON barrios_teusaquillo TO admin_usaquen WITH ADMIN OPTION` | `ORA-00993: missing GRANT keyword` |
| GRANT OPTION sobre un privilegio de objeto | `GRANT SELECT ON barrios_teusaquillo TO admin_usaquen WITH GRANT OPTION` | `Grant succeeded.` |
| GRANT OPTION sobre un privilegio de sistema (como `admin_sabanero`) | `GRANT CREATE VIEW TO admin_usaquen WITH GRANT OPTION` | `ORA-01939`. En 23ai el texto es `invalid option specified for WITH clause in the GRANT statement`; en 18c y 21c, `only the ADMIN OPTION can be specified` |

Con la GRANT OPTION, `admin_usaquen` lee la tabla y pasa el privilegio a `usuario_prueba_usaquen`. Esta vez el diccionario sí registra la cadena:

```
GRANTEE                    GRANTOR              PRIVILEGE        GRANTABLE
-------------------------- -------------------- ---------------- ---------
ADMIN_USAQUEN              ADMIN_TEUSAQUILLO    SELECT           YES
USUARIO_PRUEBA_USAQUEN     ADMIN_USAQUEN        SELECT           NO
```

La dueña revoca el privilegio solo a `admin_usaquen`, y la misma consulta queda vacía:

```
SQL> REVOKE SELECT ON barrios_teusaquillo FROM admin_usaquen;

Revoke succeeded.

no rows selected
```

**Conclusión:** las tareas E y F tienen la misma estructura (A delega a B, B delega a C y se le revoca a B), pero el resultado es opuesto. Con un privilegio de objeto, Oracle conoce el `GRANTOR` y revoca en cascada. Con un rol no lo conoce, y `usuario_prueba_usaquen`, el equivalente de `admin_usaquen` en E, habría conservado el acceso. Cada cláusula solo funciona con su tipo de privilegio: ADMIN OPTION con privilegios de sistema y roles, GRANT OPTION con privilegios de objeto.

## 4. Pregunta de exposición: riesgos de `WITH ADMIN OPTION`

### Riesgos

1. **Delegación sin límite.** Quien recibe la ADMIN OPTION puede otorgar el rol a cualquier usuario, y también otorgarlo con ADMIN OPTION, así que la cadena puede crecer sin que el administrador central intervenga. En una prueba complementaria, fuera del script, `admin_teusaquillo` ejecutó `GRANT rol_admin_local TO usuario_prueba_teusaquillo WITH ADMIN OPTION` y obtuvo `Grant succeeded.`
2. **Poder de revocar a cualquiera, incluso al creador.** Otra prueba complementaria en 23ai: `admin_teusaquillo` le revocó el rol a quien se lo dio.

   ```
   SQL> REVOKE rol_admin_local FROM admin_sabanero;

   Revoke succeeded.

   SQL> CONNECT admin_sabanero/Sabanero123@localhost:1521/FREEPDB1
   Connected.
   SQL> GRANT rol_admin_local TO usuario_prueba_usaquen;
   GRANT rol_admin_local TO usuario_prueba_usaquen
         *
   ERROR at line 1:
   ORA-01924: Role "ROL_ADMIN_LOCAL" not granted or does not exist.
   ```

   El administrador central perdió el control de su propio rol. Un administrador delegado podría usar esto para dejar fuera a la oficina central.
3. **Accesos huérfanos.** Como las revocaciones no se propagan en cascada (tarea 16), los accesos que repartió un administrador siguen vigentes cuando él pierde el rol, por ejemplo cuando sale de la entidad.
4. **Trazabilidad débil.** `DBA_ROLE_PRIVS` no tiene columna de otorgante, así que el diccionario no responde quién le dio un rol a quién. Esa información solo existe si se auditan las sentencias `GRANT` y `REVOKE`.

**Mitigaciones:** otorgar solo lo necesario [3]; reservar la ADMIN OPTION para la administración central; revisar periódicamente `DBA_ROLE_PRIVS WHERE admin_option = 'YES'`; auditar los `GRANT` y `REVOKE`; y, cuando un administrador delegado sale, revocar a mano lo que repartió.

### Escenarios del ejercicio

- **Uso apropiado: `rol_admin_local` para `admin_teusaquillo` (tarea 6).** La localidad necesita incorporar a sus propios administradores, como `admin_usaquen`, sin pasar cada vez por la oficina central. El riesgo está acotado: el *contenido* del rol lo sigue definiendo `admin_sabanero`, y las tareas 10-11 mostraron que la oficina central puede retirar un privilegio a todos los delegados con una sola sentencia.
- **Uso no apropiado: `rol_auditor` para `admin_teusaquillo` (tarea 13).** Un rol de auditoría exige separación de funciones: el auditado no debería decidir quién audita. Las tareas 14-16 muestran la consecuencia: al revocarle el rol a `admin_teusaquillo`, el acceso que ella dio a `admin_usaquen` quedó vigente y sin rastro de su origen. Este rol debe otorgarlo solo la oficina central y sin ADMIN OPTION.

## 5. Conclusiones

- Los roles centralizan la administración: revocar el rol (tarea 5) o un privilegio del rol (tarea 10) afecta a todos sus usuarios con una sola sentencia.
- La ADMIN OPTION sobre un rol delega la *administración del rol*, no la de los otros privilegios del usuario (tarea 7) ni la del contenido del rol (tarea 11).
- La revocación de un rol no se propaga en cascada (tarea 16); la de un privilegio de objeto sí (tarea 17). La diferencia está en que Oracle registra el otorgante solo para los privilegios de objeto.
- Por eso la ADMIN OPTION debe darse con criterio: es apropiada para delegar operación local y riesgosa para roles de control como la auditoría.

## Referencias

1. Oracle. *Database SQL Language Reference 19c — GRANT*. https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/GRANT.html
2. Oracle. *Database SQL Language Reference 19c — REVOKE*. https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/REVOKE.html
3. Oracle. *Database Security Guide 19c — Configuring Privilege and Role Authorization*. https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-privilege-and-role-authorization.html
4. Oracle. *Database Security Guide 19c — Revokes of Privileges and Roles from a User*. https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/revokes-privileges-and-roles-user.html
