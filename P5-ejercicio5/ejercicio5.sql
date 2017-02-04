create or replace package P5
as
    type TipoRegRs is record
    (
        nombre_r    dba_cons_columns.constraint_name%type,
        nombre_t    dba_cons_columns.table_name%type,
        nombre_c    dba_cons_columns.column_name%type,
        nombre_p    dba_cons_columns.owner%type,
        tipo_r      dba_constraints.constraint_type%type,
        cond_bus    dba_constraints.search_condition%type
    );
    type TipoTablaRs is table of TipoRegRs
        index by binary_integer;

    TablaRs TipoTablaRs;

    procedure restricciones (p_nombreTabla dba_tables.table_name%type);
end P5;
/

create or replace package body P5
as
    procedure rellenarTRestrict (p_nombreTabla dba_tables.table_name%type)
    is
        cursor c_restrict is
            select c.constraint_name, c.table_name, c.column_name, c.owner
            r.constraint_type, r.search_condition
            from dba_cons_columns c, dba_constraints r
            where lower(c.table_name) = lower(c.p_nombreTabla)
            and c.table_name = r.table_name
            and c.owner = r.owner;
    begin
        null;
    end rellenarTRestrict;

    function existeTabla (p_nombre dba_tables.table_name%type)
    return boolean
    is
        v_cant      number;
        v_existe    boolean := true;
    begin
        select count(table_name) into v_cant
        from dba_tables
        where lower(table_name) = p_nombre;
        if v_cant < 1 then
            v_existe := false;
        end if;
        return v_existe;
    end existeTabla;

    procedure restricciones (p_nombreTabla dba_tables.table_name%type)
    is
    begin
        if existeTabla(p_nombreTabla) then
            rellenarTRestrict(p_nombreTabla);
        end if;
    end restricciones;
end P5;
/

