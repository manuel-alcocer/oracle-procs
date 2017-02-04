create or replace package P5
as
    procedure restricciones (nombreTabla dba_tables.table_name%type);
end P5;
/

create or replace package body P5
as
    procedure restricciones (nombreTabla dba_tables.table_name%type)
    is
    begin
        NULL;
    end restricciones;
end P5;
/

