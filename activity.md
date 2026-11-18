# Database User Management Workshop Guide — Chapter 5
*Course: Database Administration*

---

## ASSIGMENT SPECIFICATIONS

### WORKSHOP #4 – USER, PRIVILEGES AND ROLES

Dear students, good day!

Below are the conditions for the delivery of third workshop:

- **Qualification:** 10%
- **Delivery dates:** Check the document: Compromiso Académico
- **Delivery artefacts details:**
  1. sql script with the sql commands fully functional to be run in any environment.
  2. document report showing the steps and results.
  3. present and explain live in real time the execution of the script.

**Notes:**

- the script must run directly without errors
- the team must submit the report under the assignment defined on TEAMS platform for this workshop

Good luck and success!

---

## 14. LA SABANA

**Scenario:** The "Alcaldía de Bogotá" is managing permissions for district administrators. You need to delegate some administrative responsibilities securely.

**Tasks:**

1. As `admin_sabanero`, create a role named `rol_admin_local`.
2. Grant the `CREATE TABLE`, `CREATE VIEW`, and `CREATE USER` privileges to `rol_admin_local`.
3. Create a user `admin_teusaquillo` and grant her the `rol_admin_local` role.
4. Log in as `admin_teusaquillo` and verify she can create a table and a new user.
5. As `admin_sabanero`, revoke the `rol_admin_local` role from `admin_teusaquillo`.
6. Now, grant the `rol_admin_local` role to `admin_teusaquillo` `WITH ADMIN OPTION`.
7. Log in as `admin_teusaquillo` and create a new user `admin_usaquen`.
8. As `admin_teusaquillo`, grant the `rol_admin_local` role to `admin_usaquen`.
9. Log in as `admin_usaquen` and verify they can also create tables and users.
10. As `admin_sabanero`, revoke the `CREATE USER` privilege from the `rol_admin_local` role.
11. Check if `admin_teusaquillo` and `admin_usaquen` can still create users. Document your findings and explain the behavior.
12. Create a new role `rol_auditor`. Do not grant any privileges yet.
13. Grant the `rol_auditor` role to `admin_teusaquillo` `WITH ADMIN OPTION`.
14. As `admin_teusaquillo`, grant `rol_auditor` to `admin_usaquen`.
15. As `admin_sabanero`, revoke the `rol_auditor` role from `admin_teusaquillo`.
16. Check if `admin_usaquen` still has the `rol_auditor` role. Document and explain the result.
17. Demonstrate the difference between `WITH ADMIN OPTION` and `WITH GRANT OPTION` for object privileges by attempting to use each.

**Presentation Question:** What are the significant security risks associated with using `WITH ADMIN OPTION`? Describe a real-world administrative scenario from this exercise where its use is appropriate and one where it is not.
