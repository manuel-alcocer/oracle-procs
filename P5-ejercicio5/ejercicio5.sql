create or replace package P5
as
    procedure restricciones (p_nombreTabla dba_tables.table_name%type);
end P5;
/

create or replace package body P5
as
    function existeTabla (p_nombre dba_tables.table_name%type)
    return boolean
    is
        v_cant number;
        v_existe boolean := true;
    begin
        select count(table_name) into v_cant from dba_tables
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
            null;
        end if;
    end restricciones;
end P5;
/

