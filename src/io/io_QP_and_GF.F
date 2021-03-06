!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
integer function io_QP_and_GF(what,qp,ID)
 use pars,           ONLY:SP,schlen
 use D_lattice,      ONLY:alat
 use memory_m,       ONLY:mem_est
 use electrons,      ONLY:n_sp_pol
 use QP_m,           ONLY:QP_t,QP_G_dr,QP_G_er,&
&                         GWo_iterations,GF_is_causal,QP_G_Zoom_treshold
 use IO_m,           ONLY:io_connect,io_disconnect,io_sec,io_header,&
&                         io_elemental,io_status,io_bulk,read_is_on,&
&                         write_is_on,io_mode,DUMP,VERIFY,DB_is_OK,&
&                         db_alat,variable_is_found,IO_INCOMPATIBLE_VAR,IO_NO_BINDING_ERROR
 use global_XC,      ONLY:QP_DB_kind,SE_GoWo,SE_GWo,SE_GoWo_PPA,SE_GWo_PPA,SE_COHSEX,SE_NONE,&
&                         SE_POLARON,SE_GW_QED
 !
 implicit none
 type(QP_t)  ::qp
 character(*)::what ! 'QP'/'G'/filename
 integer     ::ID
 !
 ! Work Space
 !
 integer              ::i1,i2,i_found,&
&                       QP_nk_disk,QP_nb_disk,QP_n_states_disk,n_descs_disk,&
&                       QP_DB_kind_disk 
 character(schlen)    ::ch
 integer ,    allocatable ::qp_table_disk(:,:)
 real(SP),    allocatable ::qp_DATA_disk(:,:,:)
 !
 if (what=="QP".or.what=="G") then
   io_QP_and_GF=io_connect(desc=what,type=2,ID=ID)
 else
   io_QP_and_GF=io_connect(desc=what,type=-3,ID=ID)
 endif
 if (io_QP_and_GF/=0) goto 1
 !
 if (any((/io_sec(ID,:)==1/))) then
   ! 
   ! This routine can be
   ! used to apply QP corrections. In this case QP_DB_kind must be 
   ! present to be transferred in the energy type by mod_qp_ctl
   !
   if (variable_is_found(ID,"QP_DB_kind")==1.or.write_is_on(ID)) then
     call io_elemental(ID,VAR="QP_DB_kind",VAR_SZ=1,MENU=0)
     call io_elemental(ID,DB_I0=QP_DB_kind_disk,I0=QP_DB_kind)
     if(io_mode(ID)==VERIFY) then
        if(QP_DB_kind_disk/=QP_DB_kind) then
          io_QP_and_GF=IO_INCOMPATIBLE_VAR
          return
        endif
     endif
     call io_elemental(ID,VAR="",VAR_SZ=0,MENU=0)
   else if (variable_is_found(ID,"QP_DB_kind")< 0.and.read_is_on(ID)) then
     QP_DB_kind=0
     io_QP_and_GF=IO_INCOMPATIBLE_VAR
     return
   endif
   !
 endif
 !
 ! QP_DB_kind points to the "type" of self-energy. This is used
 ! to report about XC kind of the components of the self-energy here
 ! and it is also later transfered to the G/X .. global kinds in mod_qp_ctl.
 !
 select case (QP_DB_kind)
   case(0,SE_NONE)
     io_QP_and_GF=io_header(ID,T_EL=.true.,D_LATT=.true.,CUTOFF=.true.)
   case(SE_COHSEX)
     io_QP_and_GF=io_header(ID,T_EL=.true.,D_LATT=.true.,XC_KIND="G_WF Xs",CUTOFF=.true.)
   case(SE_GoWo_PPA,SE_GWo_PPA)
     io_QP_and_GF=io_header(ID,T_EL=.true.,D_LATT=.true.,XC_KIND="G Xp",CUTOFF=.true.)
   case(SE_GoWo,SE_GWo)
     io_QP_and_GF=io_header(ID,T_EL=.true.,D_LATT=.true.,XC_KIND="G Xd",CUTOFF=.true.)
   case(SE_POLARON,SE_GW_QED)
     io_QP_and_GF=io_header(ID,T_EL=.true.,D_LATT=.true.,XC_KIND="G",CUTOFF=.true.)
 end select
 !
 if (io_QP_and_GF/=0) goto 1
 !
 call io_elemental(ID,VAR="PARS",VAR_SZ=5,MENU=0)
 call io_elemental(ID,I0=qp%nb,DB_I0=QP_nb_disk,CHECK=.true.,OP=(/"<="/))
 call io_elemental(ID,I0=qp%nk,DB_I0=QP_nk_disk,CHECK=.true.,OP=(/"<="/))
 call io_elemental(ID,I0=qp%n_states,DB_I0=QP_n_states_disk,&
&                  VAR=' QP tot states          :',CHECK=.true.,OP=(/"<="/))
 call io_elemental(ID,I0=GWo_iterations,&
&                  VAR=' GW SC iterations       :',CHECK=.true.,OP=(/"=="/))
 call io_elemental(ID,I0=qp%n_descs,DB_I0=n_descs_disk,CHECK=.true.,OP=(/"<="/))
 call io_elemental(ID,VAR="",VAR_SZ=0,MENU=0)
 !
 if (index(what,".G")/=0.or.what=="G") then
   !
   ! Though the GF's parameters are already stored in the QP_descriptions
   ! I need them on-the-fly to, eventually, rebuild the Green's function
   !
   call io_elemental(ID,VAR="SE_OPERATOR_PARAMETERS",VAR_SZ=7,MENU=0)
   call io_elemental(ID,I0=qp%GreenF_n_steps)
   call io_elemental(ID,R1=QP_G_er) ! <- This is, actually, not needed as the
                                    !    full frequency dependence is stored in sec 3
   call io_elemental(ID,R1=QP_G_dr)
   call io_elemental(ID,L0=GF_is_causal)
   call io_elemental(ID,R0=QP_G_Zoom_treshold)
   call io_elemental(ID,VAR="",VAR_SZ=0,MENU=0)
   !
 endif
 !
 io_QP_and_GF=io_status(ID)
 if (.not.DB_is_OK(ID)) goto 1
 !
 if (any((/io_sec(ID,:)==2/))) then
   !
   do i1=1,n_descs_disk
     write (ch,'(a,i5.5)') 'DESC_strings_',i1
     call io_elemental(ID,VAR=trim(ch),CH0="",VAR_SZ=1,MENU=0)
     !
     ! The QP lines are skipped. The QP_state check is
     ! used instead. Also the GW SC iterations are skipped, as
     ! they are written before.
     !
     if (index(qp%description(i1),'GW SC')>0) then
       call io_elemental(ID,CH0=qp%description(i1))
       cycle
     endif
     !
     if (what=="G") then
       call io_elemental(ID,CH0=qp%description(i1),VAR='',CHECK=.true.,OP=(/"=="/)) 
       if (index(qp%description(i1),'Zoom')>0.and.io_status(ID)<0)  io_status(ID)=IO_NO_BINDING_ERROR
     else
       if (index(qp%description(i1),'QP')>0) then
         call io_elemental(ID,CH0=qp%description(i1),VAR='')
       else
         call io_elemental(ID,CH0=qp%description(i1),VAR='',CHECK=.true.,OP=(/"=="/)) 
       endif
     endif
     !
     if (i1<n_descs_disk) call io_elemental(ID,VAR="",VAR_SZ=0,MENU=0)
     if (i1==n_descs_disk) call io_elemental(ID,VAR="",VAR_SZ=0,MENU=1)
   enddo
   !
   io_QP_and_GF=io_status(ID)
   if (.not.DB_is_OK(ID)) goto 1
   !
   ! The table is used to check the requested QP states with the disk ones.
   ! Note that I do not extract the W m.e. for a subset of Qp states
   ! (too complicated) while I check in the QP case that the states 
   ! reqeusted have been not already done.
   !
   ! So to be here in VERIFY mode you MUST have allocated and defined the qp%table 
   !
   allocate(qp_table_disk(qp_n_states_disk,3+n_sp_pol-1))
   !
   if (write_is_on(ID)) qp_table_disk=qp%table
   !
   call io_bulk(ID,VAR="QP_table",VAR_SZ=(/qp_n_states_disk,3+n_sp_pol-1/))
   call io_bulk(ID,I2=qp_table_disk)
   !
   if (io_mode(ID)==VERIFY.and.associated(qp%table)) then
     do i1=1,qp%n_states
       i_found=-1
       do i2=1,qp_n_states_disk
         if (all((/qp_table_disk(i2,:)==qp%table(i1,:)/))) then
           i_found=0
         endif
       enddo
       if (i_found/=0) io_status(ID)=IO_INCOMPATIBLE_VAR
     enddo
   endif
   !
   if (io_mode(ID)==DUMP) then
     allocate(qp%table(qp_n_states_disk,3+n_sp_pol-1))
     qp%table=qp_table_disk
   endif
   !
   deallocate(qp_table_disk)
   !
   io_QP_and_GF=io_status(ID)
   if (.not.DB_is_OK(ID)) goto 1
   !
 endif
 !
 if (any((/io_sec(ID,:)==3/))) then
   !
   ! I arrive here only in DUMP mode as in qp_solver I use only sections
   ! 1 and 2 to VERIFY. IN case everything is fine I do not load the 
   ! corrections.
   !
   call io_bulk(ID,VAR="QP_kpts",VAR_SZ=(/qp%nk,3/))
   !
   if (.not.associated(qp%k))  allocate(qp%k(qp%nk,3))
   if (.not.associated(qp%wk)) allocate(qp%wk(qp%nk ))
   !
   call io_bulk(ID,R2=qp%k)
   !
   ! Davide: tmp code, to be fixed
   !
   qp%wk=0._SP
   if (read_is_on(ID)) then
     do i1=1,qp%nk
       if (.not.any(qp%table(:,3)==i1)) qp%k(i1,:)=0._SP
       qp%k(i1,:)=qp%k(i1,:)/db_alat(:)*alat(:)
     enddo
   endif
   !
   if (index(what,".QP")/=0.or.what=="QP") then
     !
     ! QP corrections 
     !
     allocate(qp_DATA_disk(3,qp%n_states,2))
     !  
     if (write_is_on(ID)) then
       do i1=1,qp%n_states
         qp_DATA_disk(1,i1,1)=real(qp%E(i1))
         qp_DATA_disk(1,i1,2)=aimag(qp%E(i1))
         qp_DATA_disk(2,i1,1)=qp%E_bare(i1)
         qp_DATA_disk(2,i1,2)=0._SP
         qp_DATA_disk(3,i1,1)=real(qp%Z(i1))
         qp_DATA_disk(3,i1,2)=aimag(qp%Z(i1))
       enddo
     endif
     !
     call io_bulk(ID,VAR="QP_E_Eo_Z",VAR_SZ=(/3,qp%n_states,2/))
     !
     call io_bulk(ID,R3=qp_DATA_disk)
     !
     if (read_is_on(ID)) then
       allocate(qp%Z(qp%n_states),qp%E(qp%n_states),qp%E_bare(qp%n_states))
       call mem_est("qp_Z qp_E qp_E_bare",(/qp%n_states,qp%n_states,qp%n_states/))
       do i1=1,qp%n_states
         qp%E(i1) =cmplx(qp_DATA_disk(1,i1,1),qp_DATA_disk(1,i1,2),SP)
         qp%E_bare(i1)=qp_DATA_disk(2,i1,1)
         qp%Z(i1) =cmplx(qp_DATA_disk(3,i1,1),qp_DATA_disk(3,i1,2),SP)
       enddo
     endif
     !
     deallocate(qp_DATA_disk)
     !
   endif
   !
   if (index(what,".G")/=0.or.what=="G") then
     !
     allocate(qp_DATA_disk(qp%n_states,qp%GreenF_n_steps,6))
     !
     ! Real axis Self Energy & Green Function 
     !=========================================
     !
     if (write_is_on(ID)) then
       do i1=1,qp%n_states
         qp_DATA_disk(i1,:,1)=real(qp%S_total(i1,:))
         qp_DATA_disk(i1,:,2)=aimag(qp%S_total(i1,:))
         qp_DATA_disk(i1,:,3)=real(qp%GreenF(i1,:))
         qp_DATA_disk(i1,:,4)=aimag(qp%GreenF(i1,:))
         qp_DATA_disk(i1,:,5)=real(qp%GreenF_W(i1,:))
         qp_DATA_disk(i1,:,6)=aimag(qp%GreenF_W(i1,:))
       enddo
     endif
     !
     call io_bulk(ID,VAR="SE_Operator",VAR_SZ=(/qp%n_states,qp%GreenF_n_steps,2/))
     call io_bulk(ID,R3=qp_DATA_disk(:,:,1:2))
     call io_bulk(ID,VAR="Green_Functions",VAR_SZ=(/qp%n_states,qp%GreenF_n_steps,2/))
     call io_bulk(ID,R3=qp_DATA_disk(:,:,3:4))
     call io_bulk(ID,VAR="Green_Functions_Energies",VAR_SZ=(/qp%n_states,qp%GreenF_n_steps,2/))
     call io_bulk(ID,R3=qp_DATA_disk(:,:,5:6))
     !
     if (read_is_on(ID)) then
       allocate(qp%S_total(qp%n_states,qp%GreenF_n_steps))
       call mem_est("qp_S_total",(/size(qp%S_total)/))
       allocate(qp%GreenF(qp%n_states,qp%GreenF_n_steps))
       call mem_est("qp_GreenF",(/size(qp%GreenF)/))
       allocate(qp%GreenF_W(qp%n_states,qp%GreenF_n_steps))
       call mem_est("qp_GreenF_W",(/size(qp%GreenF_W)/))
       do i1=1,qp%n_states
         qp%S_total(i1,:) =cmplx(qp_DATA_disk(i1,:,1),qp_DATA_disk(i1,:,2),SP)
         qp%GreenF(i1,:)  =cmplx(qp_DATA_disk(i1,:,3),qp_DATA_disk(i1,:,4),SP)
         qp%GreenF_W(i1,:)=cmplx(qp_DATA_disk(i1,:,5),qp_DATA_disk(i1,:,6),SP)
       enddo
     endif
     !
     deallocate(qp_DATA_disk)
     !
   endif
   !
   io_QP_and_GF=io_status(ID)
   if (.not.DB_is_OK(ID)) goto 1
   !
 endif
 !
1 call io_disconnect(ID=ID)
 !
end function
