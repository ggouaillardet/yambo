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
integer function io_HF_and_locXC(ID)
 !
 use pars,           ONLY:SP,schlen
 use R_lattice,      ONLY:RIM_ng,RIM_n_rand_pts
 use electrons,      ONLY:n_met_bands,n_sp_pol
 use QP_m,           ONLY:QP_Vnl_xc,QP_ng_Sx,QP_nb,QP_nk,QP_Vxc,QP_n_states,&
&                         QP_table,QP_state
 use IO_m,           ONLY:io_connect,io_disconnect,io_sec,io_header,io_HF,frag_HF,&
&                         io_elemental,io_status,io_bulk,read_is_on,IO_NOT_ALLOWED,&
&                         write_is_on,io_mode,DUMP,ver_is_gt_or_eq,IO_INCOMPATIBLE_VAR
#if defined _TIMING
 use timing_m,       ONLY:timing
#endif
 implicit none
 integer :: ID
 !
 ! Work Space
 !
 integer           :: QP_table_disk(2+n_sp_pol),&
&                     QP_n_states_disk,bands(2),i1,i2,i_found,var_sz
 real(SP)          :: Sx(2),Vxc(2)
 character(schlen) :: QP_xc_FUNCTIONAL
 !
 if (.not.io_HF) then
   io_HF_and_locXC=IO_NOT_ALLOWED
   call io_disconnect(ID,FORCE=.TRUE.)
   return
 endif
 !
#if defined _TIMING
 call timing('io_HF',OPR='start')
#endif
 !
 io_HF_and_locXC=io_connect(desc="HF_and_locXC",type=2,ID=ID,no_full_RESET=.TRUE.)
 if (io_HF_and_locXC/=0) then
   io_HF_and_locXC=io_connect(desc="xxvxc",type=2,ID=ID)
 endif
 if (io_HF_and_locXC/=0) goto 1
 !
 bands=(/1,n_met_bands/)
 !
 if (any((/io_sec(ID,:)==1/))) then
   !
   io_HF_and_locXC=io_header(ID,QPTS=.true.,R_LATT=.true.,WF=.true.,IMPOSE_SN=.true.,T_EL=.true.,&
&                               XC_KIND="G_WF force",CUTOFF=.true.,FRAG=frag_HF)
   !
   if (io_HF_and_locXC/=0) goto 1
   !
   call io_elemental(ID,VAR="PARS",VAR_SZ=8,MENU=0)
   !
   call io_elemental(ID,I0=QP_nb,CHECK=.true.,OP=(/"<="/))
   call io_elemental(ID,I0=QP_nk,CHECK=.true.,OP=(/"<="/))
   call io_elemental(ID,I0=QP_n_states,DB_I0=QP_n_states_disk,&
&       VAR=' Total number of QP states       :',CHECK=.true.,OP=(/"<="/))
   call io_elemental(ID,I0=QP_ng_Sx,&
&       VAR=' Exchange RL vectors             :',CHECK=.true.,OP=(/"=="/))
   !
   if (ver_is_gt_or_eq(ID,revision=498)) then
     call io_elemental(ID,I0=n_met_bands,VAR=' Exchange summation bands        :',CHECK=.true.,OP=(/"=="/))
   else
     call io_elemental(ID,I1=bands,&
&         VAR=' Exchange summation bands        :',CHECK=.true.,OP=(/"==","=="/))
   endif
   !
   call io_elemental(ID,I0=RIM_ng,&
&       VAR=' RIM RL components               :',CHECK=.true.,OP=(/"=="/))
   call io_elemental(ID,I0=RIM_n_rand_pts,&
&       VAR=' RIM random points               :',CHECK=.true.,OP=(/"=="/))
   !
   if (ver_is_gt_or_eq(ID,(/3,0,15/))) then
     call io_elemental(ID,VAR="",VAR_SZ=0)
   else
     call io_elemental(ID,VAR="",VAR_SZ=0,MENU=0)
     !
     ! xc Functional
     !
     call io_elemental(ID,VAR='XC_FUNCTIONAL',CH0="",VAR_SZ=1,MENU=0)
     call io_elemental(ID,CH0=QP_xc_FUNCTIONAL,&
&         VAR=' xc Functional                   :',CHECK=.true.,OP=(/"=="/))
     !
     call io_elemental(ID,VAR="",VAR_SZ=0)
   endif
   !
   io_HF_and_locXC=io_status(ID)
   if (io_HF_and_locXC/=0) goto 1
   !
 endif
 !
 i_found=0
 if (any((/io_sec(ID,:)==2/))) then
   if (io_mode(ID)==DUMP) then
     if (allocated(QP_state)) deallocate(QP_state)
     allocate(QP_state(Qp_nb,QP_nk))
     QP_state=.false.
   endif
   !  
   var_sz=(6+n_sp_pol)*QP_n_states_disk
   call io_bulk(ID,VAR="Sx_Vxc",VAR_SZ=(/var_sz/))
   do i1=1,QP_n_states_disk
     if (write_is_on(ID)) then
       QP_table_disk=QP_table(i1,:)
       Sx=(/real(QP_Vnl_xc(i1)),aimag(QP_Vnl_xc(i1))/)
       Vxc=(/real(QP_Vxc(i1)),aimag(QP_Vxc(i1))/)
     endif
     call io_bulk(ID,I1=QP_table_disk)
     call io_bulk(ID,R1=Sx)
     call io_bulk(ID,R1=Vxc)
     if (read_is_on(ID)) then
       if (io_mode(ID)==DUMP) then
         QP_state(QP_table_disk(1),QP_table_disk(3))=.true. 
       else
         do i2=1,QP_n_states
           if (all((/QP_table_disk==QP_table(i2,:)/))) then
             QP_Vnl_xc(i2)=cmplx(Sx(1),Sx(2),SP)
             QP_Vxc(i2)=cmplx(Vxc(1),Vxc(2),SP)
             i_found=i_found+1
           endif
         enddo
       endif
     endif
   enddo
   !
   if (read_is_on(ID).and.i_found/=QP_n_states) io_status(ID)=IO_INCOMPATIBLE_VAR
   io_HF_and_locXC=io_status(ID)
   if (io_HF_and_locXC/=0) goto 1
   !
 endif
 !
1 call io_disconnect(ID=ID)
 !
#if defined _TIMING
 if (io_HF) call timing('io_HF',OPR='stop')
#endif
 !
end function
