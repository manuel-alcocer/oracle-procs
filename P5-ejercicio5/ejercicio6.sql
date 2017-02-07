set serveroutput on

create or replace package P6 as
    type TipoRegObjeto is record
    (
        objeto      dba_segments.segment_name%type,
        tamanyo     number := 0
    );
    Type TipoTablaObjeto is table of TipoRegObjeto
        index by binary_integer;

    type TipoRegFichero is record
    (
        objetos     TipoTablaObjeto,
        tamanyo     number := 0
    );
    type TipoTablaFichero is table of TipoRegFichero
        index by dba_data_files.file_name%type;

    type TipoRegDispositivo is record
    (
        ficheros    TipoTablaFichero,
        Tamanyo     number := 0

    );
    type TipoTablaDispositivo is table of TipoRegDispositivo
        index by varchar2(100);

    TablaDev TipoTablaDispositivo;

    procedure MostrarAlmacenamientoUsuario (p_usuario dba_users.username%type);
end P6;
/

show err;

create or replace package body P6 as
    procedure borrarTrabajo
    is
        v_jobs number := 0;
    begin
        select count(*) into v_jobs
        from user_scheduler_jobs
        where upper(job_name) = upper('myjobp6');
        if v_jobs > 0 then
            dbms_scheduler.drop_job(job_name => upper('myjobp6'));
        end if;
    end borrarTrabajo;

    procedure crearTrabajo
    is
    begin
        dbms_scheduler.create_job ( job_name    => 'myjobp6',
                                    job_type    => 'executable',
                                    job_action  => '/home/oracle/get_device.sh',
                                    number_of_arguments => 1,
                                    auto_drop   => true);
    end crearTrabajo;

    procedure RellenarArchivos (p_dispositivo   varchar2,
                                p_fichero       dba_data_files.file_name%type,
                                p_usuario       dba_users.username%type)
    is
        cursor c_objetos is
            select distinct segment_name, bytes
            from dba_segments
            where header_file in (
                                    select file_id
                                    from dba_data_files
                                    where lower(file_name) = lower(p_fichero))
            and lower(owner) = lower(p_usuario);
        v_indice binary_integer := 0;
    begin
        for v_objeto in c_objetos loop
            TablaDev(p_dispositivo).ficheros(p_fichero).objetos(v_indice).objeto := v_objeto.segment_name;
            TablaDev(p_dispositivo).ficheros(p_fichero).objetos(v_indice).tamanyo := v_objeto.bytes/1024;
            TablaDev(p_dispositivo).ficheros(p_fichero).tamanyo :=
                    TablaDev(p_dispositivo).ficheros(p_fichero).tamanyo + v_objeto.bytes/1024;
            TablaDev(p_dispositivo).tamanyo := TablaDev(p_dispositivo).tamanyo + v_objeto.bytes/1024;
            v_indice := v_indice + 1;
        end loop;
    end RellenarArchivos;

    procedure RellenarDispositivos (p_usuario dba_users.username%type)
    is
        cursor c_dispositivos
        is
            select distinct file_name
            from dba_data_files
            where tablespace_name in (
                                        select tablespace_name from dba_users
                                        where lower(username) = lower(p_usuario)
                                     );
        v_nombre varchar2(100);
    begin
        for v_dispositivo in c_dispositivos loop
            dbms_scheduler.set_job_argument_value ('myjobp6', 1, v_dispositivo.file_name);
            dbms_scheduler.run_job ('myjobp6');
            select nombre into v_nombre
            from dispositivo;
            RellenarArchivos (v_nombre, v_dispositivo.file_name, p_usuario);
            --RellenarArchivos ('/dev/vda1', v_dispositivo.file_name, p_usuario);
        end loop;
    end RellenarDispositivos;

    procedure MostrarDispositivos
    is
        v_dev   varchar2(100);
        v_file  dba_data_files.file_name%type;
        v_obj   dba_segments.segment_name%type;
        v_indice number := 1;
    begin
        v_dev := TablaDev.FIRST;
        while v_dev is not null loop
            dbms_output.put_line('Dispositivo: ' || v_dev || ' -->> ' ||
                TablaDev(v_dev).tamanyo || ' KB');
            v_file := TablaDev(v_dev).ficheros.FIRST;
            while v_file is not null loop
                dbms_output.put_line(chr(9) || 'fichero: ' || v_file || ' -->> ' ||
                    TablaDev(v_dev).ficheros(v_file).tamanyo || ' KB');
                v_obj := TablaDev(v_dev).ficheros(v_file).objetos.FIRST;
                while v_obj is not null loop
                    dbms_output.put_line(chr(9) || chr(9) || v_indice || '. Objeto: ' || 
                        TablaDev(v_dev).ficheros(v_file).objetos(v_obj).objeto);
                    dbms_output.put_line(chr(9) || chr(9) || chr(9) || 'Tamanyo: ' ||
                        TablaDev(v_dev).ficheros(v_file).objetos(v_obj).tamanyo || ' KB');
                    v_obj := TablaDev(v_dev).ficheros(v_file).objetos.next(v_obj);
                    v_indice := v_indice + 1;
                end loop;
                v_file := TablaDev(v_dev).ficheros.next(v_file);
            end loop;
            v_dev := TablaDev.next(v_dev);
        end loop;
    end MostrarDispositivos;

    procedure MostrarAlmacenamientoUsuario (p_usuario dba_users.username%type)
    is
    begin
        borrarTrabajo;
        crearTrabajo;
        RellenarDispositivos (p_usuario);
        MostrarDispositivos;
        borrarTrabajo;
    end MostrarAlmacenamientoUsuario;
end P6;
/

show err;

