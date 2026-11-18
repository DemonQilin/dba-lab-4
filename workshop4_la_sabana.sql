-- =====================================================================
-- Workshop #4 - Users, Privileges and Roles
-- Case 14: LA SABANA (Alcaldia de Bogota, district administrators)
--
-- How to run (SQL*Plus, Oracle 12c or later):
--   sqlplus /nolog @workshop4_la_sabana.sql
-- The script asks for the SYSTEM password and creates everything it
-- needs. It can be run again: it starts by dropping its own users and
-- roles. Close any other session of the workshop users before running.
--
-- If your pluggable database has another service name (for example
-- XEPDB1 or ORCLPDB), change the DEFINE below. Always use the PDB:
-- in the CDB root CREATE USER fails with ORA-65096.
-- =====================================================================

SET ECHO ON
SET VERIFY OFF
SET FEEDBACK ON
SET LINESIZE 200
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN usuario        FORMAT A26
COLUMN contenedor     FORMAT A12
COLUMN username       FORMAT A26
COLUMN grantee        FORMAT A26
COLUMN grantor        FORMAT A20
COLUMN owner          FORMAT A20
COLUMN granted_role   FORMAT A16
COLUMN role           FORMAT A16
COLUMN privilege      FORMAT A16
COLUMN table_name     FORMAT A20
COLUMN admin_option   FORMAT A12
COLUMN default_role   FORMAT A12
COLUMN grantable      FORMAT A9
COLUMN nombre         FORMAT A30

DEFINE conn = localhost:1521/FREEPDB1
ACCEPT system_pwd CHAR PROMPT 'Password for SYSTEM: ' HIDE

-- Any unexpected error stops the script. Expected errors are wrapped
-- in WHENEVER SQLERROR CONTINUE and documented next to the statement.
WHENEVER SQLERROR EXIT FAILURE

-- =====================================================================
-- Setup (as SYSTEM): clean previous runs and create admin_sabanero
-- =====================================================================
CONNECT system/"&system_pwd"@&conn

SELECT USER AS usuario, SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

-- Drop only "does not exist" errors (ORA-01918 user, ORA-01919 role);
-- anything else (for example ORA-01940, user still connected) is raised.
DECLARE
  PROCEDURE drop_user(p_name IN VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP USER ' || p_name || ' CASCADE';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE != -1918 THEN
        RAISE;
      END IF;
  END drop_user;

  PROCEDURE drop_role(p_name IN VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP ROLE ' || p_name;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE != -1919 THEN
        RAISE;
      END IF;
  END drop_role;
BEGIN
  drop_user('usuario_prueba_teusaquillo');
  drop_user('usuario_prueba_usaquen');
  drop_user('admin_usaquen');
  drop_user('admin_teusaquillo');
  drop_user('admin_sabanero');
  drop_role('rol_admin_local');
  drop_role('rol_auditor');
END;
/

-- admin_sabanero is the district super administrator. To build the
-- role and hand out its privileges it needs:
--   CREATE ROLE                             -> tasks 1 and 12
--   CREATE TABLE/VIEW/USER WITH ADMIN OPTION -> grant them to the role
--                                              (task 2), revoke CREATE
--                                              USER from it (task 10)
--   CREATE USER                             -> create admin_teusaquillo
--   CREATE SESSION WITH ADMIN OPTION        -> log in, and let the
--                                              district admins log in
CREATE USER admin_sabanero IDENTIFIED BY Sabanero123;
GRANT CREATE SESSION TO admin_sabanero WITH ADMIN OPTION;
GRANT CREATE ROLE TO admin_sabanero;
GRANT CREATE TABLE, CREATE VIEW, CREATE USER TO admin_sabanero WITH ADMIN OPTION;

-- =====================================================================
-- Task 1. As admin_sabanero, create the role rol_admin_local
-- =====================================================================
CONNECT admin_sabanero/Sabanero123@&conn

SELECT USER AS usuario, SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

CREATE ROLE rol_admin_local;

-- The creator of a role receives it automatically WITH ADMIN OPTION.
SELECT granted_role, admin_option
FROM user_role_privs
WHERE granted_role = 'ROL_ADMIN_LOCAL';

-- =====================================================================
-- Task 2. Grant CREATE TABLE, CREATE VIEW and CREATE USER to the role
-- =====================================================================
GRANT CREATE TABLE, CREATE VIEW, CREATE USER TO rol_admin_local;

SELECT role, privilege, admin_option
FROM role_sys_privs
WHERE role = 'ROL_ADMIN_LOCAL'
ORDER BY privilege;

-- =====================================================================
-- Task 3. Create admin_teusaquillo and grant her rol_admin_local
-- =====================================================================
-- CREATE SESSION is not part of the role, so it is granted directly.
-- The quota lets her insert rows in the tables she creates.
CREATE USER admin_teusaquillo IDENTIFIED BY Teusa123
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT CREATE SESSION TO admin_teusaquillo;
GRANT rol_admin_local TO admin_teusaquillo;

-- =====================================================================
-- Task 4. As admin_teusaquillo, verify she can create a table and a user
-- =====================================================================
CONNECT admin_teusaquillo/Teusa123@&conn

SELECT granted_role, admin_option, default_role
FROM user_role_privs;

SELECT privilege FROM session_privs ORDER BY privilege;

CREATE TABLE prueba_teusaquillo (
  id     NUMBER PRIMARY KEY,
  nombre VARCHAR2(50)
);
INSERT INTO prueba_teusaquillo VALUES (1, 'Prueba tarea 4');
COMMIT;
SELECT * FROM prueba_teusaquillo;

CREATE USER usuario_prueba_teusaquillo IDENTIFIED BY Prueba123;

SELECT username FROM all_users
WHERE username = 'USUARIO_PRUEBA_TEUSAQUILLO';

-- =====================================================================
-- Task 5. As admin_sabanero, revoke rol_admin_local from admin_teusaquillo
-- =====================================================================
CONNECT admin_sabanero/Sabanero123@&conn

REVOKE rol_admin_local FROM admin_teusaquillo;

-- A role revoke applies to new sessions, so we check from a new one.
-- Only the directly granted CREATE SESSION remains.
CONNECT admin_teusaquillo/Teusa123@&conn

SELECT granted_role FROM user_role_privs;
SELECT privilege FROM session_privs ORDER BY privilege;

-- =====================================================================
-- Task 6. Grant rol_admin_local to admin_teusaquillo WITH ADMIN OPTION
-- =====================================================================
CONNECT admin_sabanero/Sabanero123@&conn

GRANT rol_admin_local TO admin_teusaquillo WITH ADMIN OPTION;

-- =====================================================================
-- Task 7. As admin_teusaquillo, create the user admin_usaquen
-- =====================================================================
CONNECT admin_teusaquillo/Teusa123@&conn

-- ADMIN_OPTION = YES: she can now grant and revoke the role herself.
SELECT granted_role, admin_option, default_role
FROM user_role_privs;

CREATE USER admin_usaquen IDENTIFIED BY Usaquen123
  DEFAULT TABLESPACE users QUOTA 10M ON users;

-- Expected error: ORA-01031: insufficient privileges.
-- WITH ADMIN OPTION on the role lets her delegate the role, not the
-- privileges she holds outside it. CREATE SESSION was granted to her
-- without ADMIN OPTION, so she cannot pass it on. admin_sabanero
-- grants it below, before task 9.
WHENEVER SQLERROR CONTINUE
GRANT CREATE SESSION TO admin_usaquen;
WHENEVER SQLERROR EXIT FAILURE

-- =====================================================================
-- Task 8. As admin_teusaquillo, grant rol_admin_local to admin_usaquen
-- =====================================================================
-- Allowed thanks to the WITH ADMIN OPTION received in task 6.
GRANT rol_admin_local TO admin_usaquen;

-- Support step: admin_usaquen needs CREATE SESSION to log in (task 9).
CONNECT admin_sabanero/Sabanero123@&conn

GRANT CREATE SESSION TO admin_usaquen;

-- =====================================================================
-- Task 9. As admin_usaquen, verify they can also create tables and users
-- =====================================================================
CONNECT admin_usaquen/Usaquen123@&conn

-- ADMIN_OPTION = NO: admin_usaquen can use the role, not delegate it.
SELECT granted_role, admin_option, default_role
FROM user_role_privs;

SELECT privilege FROM session_privs ORDER BY privilege;

CREATE TABLE prueba_usaquen (
  id     NUMBER PRIMARY KEY,
  nombre VARCHAR2(50)
);
INSERT INTO prueba_usaquen VALUES (1, 'Prueba tarea 9');
COMMIT;
SELECT * FROM prueba_usaquen;

CREATE USER usuario_prueba_usaquen IDENTIFIED BY Prueba123;

SELECT username FROM all_users
WHERE username = 'USUARIO_PRUEBA_USAQUEN';

-- =====================================================================
-- Task 10. As admin_sabanero, revoke CREATE USER from rol_admin_local
-- =====================================================================
CONNECT admin_sabanero/Sabanero123@&conn

REVOKE CREATE USER FROM rol_admin_local;

SELECT role, privilege, admin_option
FROM role_sys_privs
WHERE role = 'ROL_ADMIN_LOCAL'
ORDER BY privilege;

-- =====================================================================
-- Task 11. Can admin_teusaquillo and admin_usaquen still create users?
-- =====================================================================
CONNECT admin_teusaquillo/Teusa123@&conn

SELECT privilege FROM session_privs ORDER BY privilege;

-- Expected error: ORA-01031: insufficient privileges.
WHENEVER SQLERROR CONTINUE
CREATE USER otro_teusaquillo IDENTIFIED BY Otro123;
WHENEVER SQLERROR EXIT FAILURE

CONNECT admin_usaquen/Usaquen123@&conn

SELECT privilege FROM session_privs ORDER BY privilege;

-- Expected error: ORA-01031: insufficient privileges.
WHENEVER SQLERROR CONTINUE
CREATE USER otro_usaquen IDENTIFIED BY Otro123;
WHENEVER SQLERROR EXIT FAILURE

-- Findings: neither user can create users anymore. Both received
-- CREATE USER only through rol_admin_local, so removing it from the
-- role removes it from every grantee at once, with no change to their
-- accounts (and it takes effect even in sessions already open).
-- WITH ADMIN OPTION does not protect admin_teusaquillo: it lets her
-- administer the role, not keep privileges the role no longer has.
-- Objects created earlier are kept: admin_usaquen and both
-- usuario_prueba_* users still exist.

-- =====================================================================
-- Task 12. Create the role rol_auditor, without privileges
-- =====================================================================
CONNECT admin_sabanero/Sabanero123@&conn

CREATE ROLE rol_auditor;

-- The three queries return no rows: the role is empty.
SELECT role, privilege FROM role_sys_privs WHERE role = 'ROL_AUDITOR';
SELECT role, owner, table_name, privilege FROM role_tab_privs WHERE role = 'ROL_AUDITOR';
SELECT role, granted_role FROM role_role_privs WHERE role = 'ROL_AUDITOR';

-- =====================================================================
-- Task 13. Grant rol_auditor to admin_teusaquillo WITH ADMIN OPTION
-- =====================================================================
GRANT rol_auditor TO admin_teusaquillo WITH ADMIN OPTION;

-- =====================================================================
-- Task 14. As admin_teusaquillo, grant rol_auditor to admin_usaquen
-- =====================================================================
CONNECT admin_teusaquillo/Teusa123@&conn

GRANT rol_auditor TO admin_usaquen;

CONNECT system/"&system_pwd"@&conn

SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee IN ('ADMIN_TEUSAQUILLO', 'ADMIN_USAQUEN')
ORDER BY granted_role, grantee;

-- =====================================================================
-- Task 15. As admin_sabanero, revoke rol_auditor from admin_teusaquillo
-- =====================================================================
CONNECT admin_sabanero/Sabanero123@&conn

REVOKE rol_auditor FROM admin_teusaquillo;

-- =====================================================================
-- Task 16. Does admin_usaquen still have rol_auditor?
-- =====================================================================
CONNECT admin_usaquen/Usaquen123@&conn

SELECT granted_role, admin_option, default_role
FROM user_role_privs
ORDER BY granted_role;

SELECT role FROM session_roles ORDER BY role;

CONNECT system/"&system_pwd"@&conn

SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE granted_role = 'ROL_AUDITOR';

-- Result: admin_usaquen still has rol_auditor, admin_teusaquillo does
-- not. Revoking a role (or a system privilege) does not cascade, even
-- when it was granted WITH ADMIN OPTION: Oracle does not keep the
-- chain of who granted it to whom. Every grant made by
-- admin_teusaquillo survives her revoke, and must be found and
-- revoked one by one (for example querying DBA_ROLE_PRIVS).

-- =====================================================================
-- Task 17. WITH ADMIN OPTION vs WITH GRANT OPTION (object privileges)
-- =====================================================================
-- admin_teusaquillo owns a table, so she can grant object privileges
-- on it (CREATE TABLE still comes from rol_admin_local).
CONNECT admin_teusaquillo/Teusa123@&conn

CREATE TABLE barrios_teusaquillo (
  id     NUMBER PRIMARY KEY,
  nombre VARCHAR2(50)
);
INSERT INTO barrios_teusaquillo VALUES (1, 'La Soledad');
INSERT INTO barrios_teusaquillo VALUES (2, 'Galerias');
COMMIT;

-- Attempt 1: ADMIN OPTION on an object privilege.
-- Expected error: ORA-00993: missing GRANT keyword.
-- WITH ADMIN OPTION only exists for system privileges and roles.
WHENEVER SQLERROR CONTINUE
GRANT SELECT ON barrios_teusaquillo TO admin_usaquen WITH ADMIN OPTION;
WHENEVER SQLERROR EXIT FAILURE

-- Attempt 2: GRANT OPTION on the object privilege. It works.
GRANT SELECT ON barrios_teusaquillo TO admin_usaquen WITH GRANT OPTION;

-- Attempt 3: GRANT OPTION on a system privilege.
-- Expected error: ORA-01939. The text depends on the version:
--   18c/19c/21c: only the ADMIN OPTION can be specified
--   23ai:        invalid option specified for WITH clause in the GRANT
--                statement
-- WITH GRANT OPTION only exists for object privileges.
CONNECT admin_sabanero/Sabanero123@&conn

WHENEVER SQLERROR CONTINUE
GRANT CREATE VIEW TO admin_usaquen WITH GRANT OPTION;
WHENEVER SQLERROR EXIT FAILURE

-- admin_usaquen uses the GRANT OPTION: reads the table and passes the
-- privilege on to usuario_prueba_usaquen.
CONNECT admin_usaquen/Usaquen123@&conn

SELECT * FROM admin_teusaquillo.barrios_teusaquillo ORDER BY id;

GRANT SELECT ON admin_teusaquillo.barrios_teusaquillo TO usuario_prueba_usaquen;

CONNECT system/"&system_pwd"@&conn

SELECT grantee, grantor, privilege, grantable
FROM dba_tab_privs
WHERE owner = 'ADMIN_TEUSAQUILLO' AND table_name = 'BARRIOS_TEUSAQUILLO'
ORDER BY grantee;

-- The owner revokes the privilege from admin_usaquen only.
CONNECT admin_teusaquillo/Teusa123@&conn

REVOKE SELECT ON barrios_teusaquillo FROM admin_usaquen;

-- No rows: the revoke cascaded to usuario_prueba_usaquen too.
CONNECT system/"&system_pwd"@&conn

SELECT grantee, grantor, privilege, grantable
FROM dba_tab_privs
WHERE owner = 'ADMIN_TEUSAQUILLO' AND table_name = 'BARRIOS_TEUSAQUILLO'
ORDER BY grantee;

-- Difference:
--   WITH ADMIN OPTION -> system privileges and roles. The grantee can
--     grant and revoke them to anyone. Revokes do NOT cascade
--     (task 16: admin_usaquen kept rol_auditor).
--   WITH GRANT OPTION -> object privileges only. The grantee can grant
--     them on. Oracle records the grantor, so revoking from the grantee
--     cascades to everyone who received it through them.

-- =====================================================================
-- Presentation question (answered in the report)
-- Risks of WITH ADMIN OPTION: the grantee can delegate without limit,
-- and can revoke the role from any user, even its creator (tested:
-- admin_teusaquillo can run REVOKE rol_admin_local FROM admin_sabanero);
-- revokes do not cascade, so access granted down the chain outlives
-- the delegating admin.
-- Appropriate: admin_teusaquillo with rol_admin_local (task 6), so the
-- Teusaquillo admin can onboard local admins like admin_usaquen without
-- going through the central office.
-- Not appropriate: rol_auditor (task 13). An auditor role must be
-- assigned only by the central office; delegating it let admin_usaquen
-- keep it after admin_teusaquillo lost it (task 16).
-- =====================================================================

UNDEFINE system_pwd
DISCONNECT
