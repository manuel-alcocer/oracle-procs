create or replace package P5
as
    type TipoRegCol is record
    (
        nombre_col      dba_cons_columns.column_name%type
    );
    type TipoTablaCols is table of TipoRegCol
        index by dba_cons_columns.column_name%type;

    type TipoRegRest is record
    (
        tipo_r          dba_constraints.constraint_type%type,
        cond_busc       dba_constraints.search_condition%type,
        descripcion     varchar(200),
        columnas        TipoTablaCols
    );
    type TipoTablaRest is table of TipoRegRest
        index by dba_constraints.constraint_name%type;

    type TipoRegNT is record
    (
        restricciones     TipoTablaRest
    );
    type TipoTablaNT is table of TipoRegNT
        index by dba_constraints.table_name%type;

    type TipoRegTabla is record
    (
        nombre_tabla   TipoTablaNT
    );
    type TipoTablaCS is table of TipoRegTabla
        index by dba_constraints.owner%type;

    TablaCS TipoTablaCS;

    procedure restricciones (p_nombreTabla dba_tables.table_name%type);
end P5;
/

show err;

create or replace package body P5
as
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

    function tipoRestric (p_tiporest varchar2)
    return varchar2
    is
        v_tipo varchar2(100);
    begin
        case lower(p_tiporest)
            when 'c' then v_tipo := 'Restriccion de tipo Check';
            when 'p' then v_tipo := 'Clave primaria';
            when 'u' then v_tipo := 'Clave unica';
            when 'r' then v_tipo := 'Integridad referencial (FK)';
            when 'v' then v_tipo := 'con opción check, en una vista';
            when 'o' then v_tipo := 'Con solo lectura, en una vista';
        end case;
        return v_tipo;
    end tipoRestric;
    
    function sustituirRetorno (p_cadena long)
    return varchar2
    is
        cadena varchar2(500);
    begin
        cadena := substr(p_cadena,1,499);
        cadena := replace(cadena, chr(10), ' ');
        return cadena;
    end sustituirRetorno;

    procedure rellenarTRestrict (p_nombreTabla dba_tables.table_name%type)
    is
        cursor c_restrict is
            select owner, table_name, constraint_name,
            constraint_type, search_condition
            from dba_constraints
            where lower(table_name) = lower(p_nombreTabla)
            order by owner, table_name;
    begin
        for v_r in c_restrict loop
            TablaCS(v_r.owner).nombre_tabla(v_r.table_name).restricciones(v_r.constraint_name).tipo_r
                    := v_r.constraint_type;
            TablaCS(v_r.owner).nombre_tabla(v_r.table_name).restricciones(v_r.constraint_name).cond_busc
                    := sustituirRetorno(v_r.search_condition);
            TablaCS(v_r.owner).nombre_tabla(v_r.table_name).restricciones(v_r.constraint_name).descripcion
                    := tipoRestric(v_r.constraint_type);
        end loop;
    end rellenarTRestrict;

    procedure colquery (p_prop dba_constraints.owner%type,
                        p_tabla dba_constraints.table_name%type)
    is
        cursor c_columnas is
            select column_name columna, constraint_name from dba_cons_columns
            where lower(owner) = lower(p_prop)
            and lower(table_name) = lower(p_tabla);
    begin
        for v_col in c_columnas loop
            TablaCS(p_prop).nombre_tabla(p_tabla).restricciones(v_col.constraint_name).columnas(v_col.columna).nombre_col := v_col.columna;
        end loop;
    end colquery;

    procedure rellenarTCols
    is
        v_prop      dba_constraints.owner%type := TablaCS.FIRST;
        v_tabla     dba_constraints.table_name%type;
    begin
        while v_prop is not null loop
            v_tabla := TablaCS(v_prop).nombre_tabla.FIRST;
            colquery(v_prop, v_tabla);
            v_prop := TablaCS.next(v_prop);
        end loop;
    end rellenarTCols;

    procedure mostrarCols (p_owner dba_constraints.owner%type,
                            p_table dba_constraints.table_name%type,
                            p_const dba_constraints.constraint_name%type)
    is
        v_col       dba_cons_columns.column_name%TYPE;
    begin
        v_col := TablaCS(p_owner).nombre_tabla(p_table).restricciones(p_const).columnas.FIRST;
        while v_col is not null loop
            dbms_output.put_line(chr(9) || chr(9) || '* ' || v_col);
            v_col := TablaCS(p_owner).nombre_tabla(p_table).restricciones(p_const).columnas.next(v_col);
        end loop;
    end mostrarCols;

    procedure mostrarRestric (p_owner   dba_constraints.owner%type,
                              p_table   dba_constraints.table_name%type)
    is
        v_col       dba_cons_columns.column_name%TYPE;
        v_const     dba_constraints.constraint_name%TYPE;
    begin
        v_const := TablaCS(p_owner).nombre_tabla(p_table).restricciones.FIRST;
        while v_const is not null loop
            dbms_output.put_line(chr(10) || '- Restriccion: ' || v_const || ':');
            dbms_output.put_line( chr(9) || '- Descripcion: ' || 
                                TablaCS(p_owner).nombre_tabla(p_table).restricciones(v_const).descripcion);
            if lower(TablaCS(p_owner).nombre_tabla(p_table).restricciones(v_const).tipo_r) = 'c' then
               dbms_output.put_line( chr(9) || '- Condicion de busqueda: ' );
               dbms_output.put_line( chr(9) || chr(9) || '* ' ||
                TablaCS(p_owner).nombre_tabla(p_table).restricciones(v_const).cond_busc);
            end if;
            dbms_output.put_line(chr(9) || '- Columnas: ');
            v_col := TablaCS(p_owner).nombre_tabla(p_table).restricciones(v_const).columnas.FIRST;
            mostrarCols(p_owner, p_table, v_const);
            v_const := TablaCS(p_owner).nombre_tabla(p_table).restricciones.next(v_const);
        end loop;
        dbms_output.put_line(chr(10));
    end mostrarRestric;

    procedure mostrarTRestrict
    is
        v_owner     dba_constraints.owner%TYPE;
        v_table     dba_constraints.table_name%TYPE;
    begin
        v_owner := TablaCS.FIRST;
        while v_owner is not null loop
            dbms_output.put_line(chr(10) || 'Esquema: ' || v_owner);
            v_table := TablaCS(v_owner).nombre_tabla.FIRST;
            dbms_output.put_line('Tabla: ' || v_table || chr(10) || '================');
            mostrarRestric(v_owner, v_table);
            v_table := TablaCS(v_owner).nombre_tabla.next(v_table);
            v_owner := TablaCS.next(v_owner);
        end loop;
    end mostrarTRestrict;

    procedure restricciones (p_nombreTabla dba_tables.table_name%type)
    is
    begin
        if existeTabla(p_nombreTabla) then
            rellenarTRestrict(p_nombreTabla);
            rellenarTCols;
            mostrarTRestrict;
        end if;
    end restricciones;
end P5;
/

show err;
