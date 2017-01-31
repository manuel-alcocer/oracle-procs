/*
6. Realizad un procedimiento llamado BalanceoCargaTemp que
balancee la carga de usuarios entre los tablespaces temporales
existentes. Para ello averiguará cuántos existen y asignará
los usuarios entre ellos de forma equilibrada. Si es necesario
para comprobar su funcionamiento, crea tablespaces temporales nuevos.
*/

create or replace package loadBalancer
as
    TYPE TipoRegTS is record
    (
        nombre          dba_tablespaces.tablespace_name%type,
        bloquesLibres   number,
        numUsuarios     number
    );
    TYPE TipoTablaTS is table of TipoRegTS
        index by binary_integer;

    TablaTS TipoTablaTS;

    procedure BalanceoCargaTemp;
end loadBalancer;
/

create or replace package body loadBalancer
as
    procedure RellenarBloques
    is
        cursor c_tsbloques is
            select tablespace_name, blocks_free
            from v$TEMP_SPACE_HEADER
            where blocks_free > 0
            and tablespace_name in ( select tablespace_name from dba_tablespaces
                                        where lower(status) = 'online'
                                        and lower(contents) = 'temporary')
            order by blocks_free desc;
        v_indice binary_integer := 0;
    begin
        TablaTS.delete;
        for v_tsbloque in c_tsbloques loop
            TablaTS(v_indice).nombre := v_tsbloque.tablespace_name;
            TablaTS(v_indice).bloquesLibres := v_tsbloque.blocks_free;
            v_indice := v_indice + 1;
        end loop;
    end RellenarBloques;

    procedure CalcularUsuariosporTS
    is
        v_minbloques    number;
        v_numUsuarios   number;
        v_indice        binary_integer;
    begin
        v_minbloques := TablaTS(TablaTS.last).bloquesLibres;
        v_indice := TablaTS.first;
        while v_indice is not null loop
            v_numUsuarios := floor(TablaTS(v_indice).bloquesLibres / v_minbloques);
            TablaTS(v_indice).numUsuarios := v_numUsuarios;
            v_indice := TablaTS.next(v_indice);
        end loop;
    end CalcularUsuariosporTS;

    procedure MostrarReparto
    is
        v_indice    binary_integer;
    begin
        v_indice := TablaTS.first;
        while v_indice is not null loop
            dbms_output.put_line(TablaTS(v_indice).nombre || ' - ' || 
                TablaTS(v_indice).bloquesLibres || ' - ' || 
                TablaTS(v_indice).numUsuarios );
            v_indice := TablaTS.next(v_indice);
        end loop;
    end MostrarReparto;

    function elegirTs
    return binary_integer
    is
        v_indice        binary_integer := TablaTS.first;
        v_indicemax     binary_integer := TablaTS.first;
    begin
        while v_indice is not null loop
            if TablaTS(v_indicemax).numUsuarios < TablaTS(v_indice).numUsuarios then
                v_indicemax := v_indice;
            end if;
            v_indice := TablaTS.next(v_indice);
        end loop;
        TablaTS(v_indicemax).numUsuarios := TablaTS(v_indicemax).numUsuarios - 1;
        return v_indicemax;
    end elegirTs;

    procedure AsignarUsuarios
    is
        cursor c_usuarios is
            select username from dba_users
            where lower(account_status) = 'open';
        v_indice binary_integer;
    begin
        v_indice := elegirTs;
        for v_usuario in c_usuarios loop
            execute immediate 'alter user ' || v_usuario.username || ' temporary tablespace ' || TablaTS(v_indice).nombre;
            v_indice := elegirTs;
        end loop;
    end AsignarUsuarios;

    procedure BalanceoCargaTemp
    is
    begin
        RellenarBloques;
        CalcularUsuariosporTS;
        AsignarUsuarios;
    end;
end loadBalancer;
/


-- Para ver el reparto de tablespaces usar esta select 

select u.username, u.temporary_tablespace, t.blocks_free
from dba_users u, v$TEMP_SPACE_HEADER t
where u.account_status = 'OPEN'
and u.temporary_tablespace = t.tablespace_name
order by t.blocks_free desc, u.temporary_tablespace desc;
*/
