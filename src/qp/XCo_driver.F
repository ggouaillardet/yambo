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
subroutine XCo_driver(E,k,Xk,q)
 !
 use drivers,       ONLY:l_acfdt,l_sc_run,l_real_time,l_gw0
 use pars,          ONLY:schlen,rZERO,SP,cZERO
 use com,           ONLY:msg
 use units,         ONLY:HA2EV
 use electrons,     ONLY:levels,n_sp_pol,spin,E_reset,E_duplicate
 use stderr,        ONLY:intc,real2ch
 use R_lattice,     ONLY:bz_samp
 use parallel_m,    ONLY:PP_redux_wait
 use IO_m,          ONLY:io_control,OP_RD_CL,OP_WR_CL,VERIFY,REP
 use QP_m,          ONLY:QP_table,QP_Vxc,QP_Vnl_xc,QP_n_states,Vxc_kind,Vnlxc_kind,&
&                        XCo_Hartree_Fock,QP_t,QP_nb,QP_nk,QP_reset,&
&                        report_Vnlxc,report_Sc,report_dSc
 use memory_m,      ONLY:mem_est
 use wave_func,     ONLY:WF
 use global_XC,     ONLY:WF_exx_fraction,WF_exx_screening
 !
 implicit none
 type(levels) ::E       
 type(bz_samp)::k,Xk,q
 !
 ! WorkSpace
 !
 type(levels) ::E_dummy
 !
 ! Screened Hybrids
 !
 logical                :: l_screen_hyb
 complex(SP),allocatable:: QP_Vnl_sex(:)
 !
 ! Reporting
 !
 integer           ::i_qp,ib,ik,ibp,ikp,i_s
 character(schlen) ::sec_mode_and_message(2),ch,ch_spin,nloc_fmt,loc_fmt
 logical           ::l_local
 type(QP_t)        ::qp
 !
 ! IO
 !
 integer           :: ID,io_err
 integer, external :: io_HF_and_locXC
 !
 ! Section
 !
 sec_mode_and_message(1)='*'
 sec_mode_and_message(2)='Bare local and non-local Exchange-Correlation'
 if (l_acfdt)   sec_mode_and_message(1)='p'
 l_local=.true.
 if(l_local) call section(trim(sec_mode_and_message(1)),trim(sec_mode_and_message(2)))
 !
 ! QP states setup
 !
 call QP_state_table_setup(E)
 !
 ! Logicals setup
 !
 l_screen_hyb=(WF_exx_screening.gt.rZERO) 
 !
 ! Allocation
 !
 if (.not.allocated(QP_Vnl_xc)) then
   allocate(QP_Vnl_xc(QP_n_states))
   call mem_est("QP_Vnl_xc",(/QP_n_states/))
 endif
 if (.not.allocated(QP_Vxc)) then
   allocate(QP_Vxc(QP_n_states))
   call mem_est("QP_Vxc",(/QP_n_states/))
 endif
 if (.not.allocated(QP_Vnl_sex).and.l_screen_hyb) then
   allocate(QP_Vnl_sex(QP_n_states))
   call mem_est("QP_Vnl_sex",(/QP_n_states/))
 endif
 QP_Vnl_xc=cZERO
 QP_Vxc=cZERO
 if (l_screen_hyb) QP_Vnl_sex=cZERO
 !
 !
 ! Main DB I/O
 !
 io_err=-1
 call io_control(ACTION=OP_RD_CL,COM=REP,SEC=(/1,2/),MODE=VERIFY,ID=ID)
 io_err=io_HF_and_locXC(ID)
 !
 if (io_err==0) then
   !
   call XCo_report_and_IO()
   !
   return
   !
 else
   !
   if (l_screen_hyb) then                          ! 
     call XCo_Hartree_Fock(E,k,xk,q,mode='hyb')    ! For screened hybrids calculate the 
     QP_Vnl_sex=QP_Vnl_xc                          ! model nonlocal screened exchange part
     QP_Vnl_xc=cZERO                               !  
   end if
   !
   call XCo_Hartree_Fock(E,k,xk,q)
   !
   !
 endif
 !
 ! Vxc
 !
 if (.not.l_sc_run.and..not.l_real_time) then
   !
   call XCo_local(E,Xk)
   if (.not.l_screen_hyb) then
     QP_Vxc = QP_Vxc + WF_exx_fraction*QP_Vnl_xc !Hybridize...
   else
     QP_Vxc = QP_Vxc + WF_exx_fraction*QP_Vnl_sex 
     deallocate(QP_Vnl_sex)
   endif
   !
 endif
 !
 if (.not.l_sc_run)  then
   call WF_free(WF)
   call XCo_report_and_IO()
 endif
 !
 contains
   !
   subroutine XCo_report_and_IO()
     !
     Vxc_kind='DFT'
     !
     call QP_reset(qp)
     call E_reset(E_dummy)
     call E_duplicate(E,E_dummy)
     !
     qp%nk=QP_nk
     qp%nb=QP_nb
     qp%n_states=QP_n_states
     qp%n_descs=0
     !
     report_Sc=.FALSE.
     report_Vnlxc=.TRUE.
     report_dSc=.FALSE.
     !
     allocate(qp%E(qp%n_states),qp%E_bare(qp%n_states))
     !
     ik=QP_table(1,3)
     call msg('nr','XC '//trim(Vnlxc_kind)//' and '//trim(Vxc_kind)//' [eV] @ K ['//trim(intc(ik))//'] (iku):',k%pt(ik,:))
     !
     do i_qp=1,QP_n_states
       !
       ib =QP_table(i_qp,1)
       ibp=QP_table(i_qp,2)
       ikp=QP_table(i_qp,3)
       i_s=spin(QP_table(i_qp,:))
       !
       if (ib==ibp) then
         E_dummy%E(ib,ikp,i_s)=E%E(ib,ikp,i_s)+real(QP_Vnl_xc(i_qp)-QP_Vxc(i_qp),SP)
         qp%E(i_qp)           =E_dummy%E(ib,ikp,i_s)
         qp%E_bare(i_qp)      =E%E(ib,ikp,i_s)
       endif
       !
       if (ikp/=ik) then
         ik=ikp
         call msg('nr','XC '//trim(Vnlxc_kind)//' and '//trim(Vxc_kind)//' [eV] @ K ['//trim(intc(ik))//'] (iku):',k%pt(ik,:))
       endif
       !
       ch_spin=' '
       !
       if (n_sp_pol==2.and.i_s==1) ch_spin='(up)'
       if (n_sp_pol==2.and.i_s==2) ch_spin='(dn)'
       ! 
       nloc_fmt='<'//trim(intc(ib))//trim(ch_spin)//'|'//trim(Vnlxc_kind)//'|'//trim(intc(ibp))&
&         //trim(ch_spin)//'> ='
       loc_fmt='<'//trim(intc(ib))//trim(ch_spin)//'|'//trim(Vxc_kind)//'|'//trim(intc(ibp))&
&         //trim(ch_spin)//'> ='
       !
       ch=trim(nloc_fmt)//' '//&
&        trim(real2ch(real(QP_Vnl_xc(i_qp)*HA2EV)))//' '//&
&        trim(real2ch(aimag(QP_Vnl_xc(i_qp)*HA2EV)))//' '//&
&        trim(loc_fmt)//' '//&
&        trim(real2ch(real(QP_Vxc(i_qp)*HA2EV)))//' '//&
&        trim(real2ch(aimag(QP_Vxc(i_qp)*HA2EV)))
       !
       if (i_qp/=QP_n_states) call msg('r',trim(ch))
       if (i_qp==QP_n_states) call msg('rn',trim(ch))
       !
     enddo
     !
     ! I/O
     !
     if (io_err/=0) then
       call io_control(ACTION=OP_WR_CL,COM=REP,SEC=(/1,2/),ID=ID)
       io_err=io_HF_and_locXC(ID)
     endif
     !
     ! Direct GAP
     !
     call section('+',trim(Vnlxc_kind)//' occupations report')
     call REPORT_Occupations(E_dummy)
     !
     ! Output 
     !
     if (.not.l_gw0.and..not.l_real_time) call QP_of(qp,E,-1,'hf')
     !
     ! MPI barrier
     !
     call PP_redux_wait
     !
     ! Clean up
     !
     deallocate(qp%E,qp%E_bare)
     call E_reset(E_dummy)
     call QP_reset(qp)
     !
   end subroutine
   !
end subroutine
