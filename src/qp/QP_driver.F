!
! Copyright (C) 2000-2008 A. Marini and the YAMBO team 
!              http://www.yambo-code.org
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
subroutine QP_driver(X,Xen,Xk,en,k,q,Xw)
 !
 use pars,          ONLY:SP,schlen,IP,HARTREE
 use memory_m,      ONLY:mem_est
 use drivers,       ONLY:l_life,l_ppa,l_el_corr,l_ph_corr,l_chosex
 use electrons,     ONLY:levels,n_sp_pol,spin
 use stderr,        ONLY:gen_fmt,real2ch
 use R_lattice,     ONLY:bz_samp
 use frequency,     ONLY:w_samp
 use com,           ONLY:msg
 use X_m,           ONLY:X_t
 use parser_m,      ONLY:parser
 use QP_m,          ONLY:QP_t,QP_dSc,QP_dSc_steps,QP_Vxc,QP_Sc,QP_solver,QP_table,&
&                        QP_Sx,QP_n_states,QP_nb,&
&                        QP_nk,QP_rep_string,QP_state,QP_dSc_test,QP_reset,&
&                        QP_Sc_steps,QP_G_er,QP_G_dr,QP_G,QP_W_partially_done,&
&                        GWo_iterations,CHOSEX_use_empties
 use IO_m,          ONLY:io_control,OP_RD_CL,OP_WR_CL,VERIFY,REP
 use global_XC,     ONLY:QP_DB_kind,SE_CHOSEX,SE_GoWo_PPA,SE_GoWo,SE_GWo_PPA,SE_GWo   
 implicit none
 type(levels) ::en,Xen
 type(bz_samp)::Xk,k,q
 type(X_t)    ::X
 type(w_samp) ::Xw
 !
 ! Work Space
 !
 type(QP_t)        ::qp
 integer           ::i1,io_err,ID,i_spin
 integer, external ::ioQP
 !
 ! Parser
 !
 call parser('NewtDchk',QP_dSc_test)
 call parser('UseEbands',CHOSEX_use_empties)
 !
 ! S_x/Vxc are always need if not l_life or el. correlations is
 ! skipped
 !
 if (.not.allocated(QP_Sx).and..not.allocated(QP_Vxc).and.l_el_corr.and.&
     .not.l_life) return
 !
 QP_solver='n'
 !
 ! Head message
 !
 call QP_reset(qp)
 !
 qp%n_descs=1
 if (trim(QP_solver)=='n') then
   write (qp%description(1),'(a)') ' GW solver              : Newton'
   call section('*','Dyson equation: Newton solver')
 else if (trim(QP_solver)=='s') then
   !
   !
 endif
 qp%n_descs=2
 if (l_ppa) then
   qp%description(2)=' PPA imaginary pt   [ev]:'//trim(real2ch(X%ppaE*HARTREE))
   QP_DB_kind=SE_GoWo_PPA
   !
   !
 endif
 !
 ! Basic defs
 !============
 !
 call QP_state_table_setup(en)
 !
 ! Here I copy several informations to the qp_t type.
 ! This is because I want the qp to be completely independent of the run
 ! in order to be possibly read as QP correction.
 !
 qp%nk=QP_nk
 qp%nb=QP_nb
 qp%n_states=QP_n_states
 !
 !
 call QP_descriptions(qp,X,Xw)
 !
 allocate(qp%Z(qp%n_states),qp%E(qp%n_states),&
&         qp%E_bare(qp%n_states),&
&         qp%k(qp%nk,3),qp%table(qp%n_states,3+n_sp_pol-1))
 !
 call mem_est("qp_Z qp_E qp_E_bare qp_K qp_table",&
&    (/QP_n_states,QP_n_states,QP_n_states,3*qp%nk,QP_n_states*(3+n_sp_pol-1)/),&
&    (/2*SP,       2*SP,       SP,         SP,           IP/))
 !
 qp%table=QP_table
 qp%E=0.
 !
 do i1=1,QP_n_states
   !
   i_spin=spin(QP_table(i1,:))
   !
   ! To perform the SC GWo the bare interaction are needed. Those are
   ! stored in the %E array, or in %Eo array if an initial QP correction
   ! has been added already
   !
   qp%E_bare(i1)=en%E(QP_table(i1,1),QP_table(i1,3),i_spin)
   if (associated(en%Eo)) qp%E_bare(i1)=en%Eo(QP_table(i1,1),QP_table(i1,3),i_spin)
   !
   qp%k(QP_table(i1,3),:)=k%pt(QP_table(i1,3),:)
 enddo
 !
 ! Sc energy steps. 2/3 If Newton/Secant. QP_Sc_steps 
 ! the full Green`s function is requested.
 !
 if (trim(QP_solver)=='g') then
   allocate(QP_Sc(QP_n_states,QP_Sc_steps))
   allocate(QP_G(QP_n_states,QP_Sc_steps))
   call mem_est("QP_G",(/size(QP_G)/))
 else if (.not.l_life) then
   QP_dSc_steps=2
   if (QP_dSc_test) QP_dSc_steps=3
   allocate(QP_Sc(QP_n_states,QP_dSc_steps),QP_dSc(qp%n_states,QP_dSc_steps-1))
   call mem_est("QP_dSc",(/size(QP_dSc)/))
   !
   ! QP i/o
   !
   call io_control(ACTION=OP_RD_CL,COM=REP,SEC=(/1,2/),MODE=VERIFY,ID=ID)
   io_err=ioQP('QP',qp,ID)
   if (io_err==0) return
 endif
 !
 call mem_est("QP_Sc",(/size(QP_Sc)/))
 !
 !Solver "type"
 !
 if (trim(QP_solver)=='n') then
   !
   ! NEWTON
   !
   call QP_newton(X,Xen,Xk,en,k,q,qp,Xw)
   !
   ! When the W q-loop is not completed done the S_c cannot be
   ! calculated on-fly 
   !
   if (QP_W_partially_done) return
 endif
 ! 
 !
 ! Reporting
 !
 call QP_report(.TRUE.,.FALSE.)
 !
 contains 
   !
   subroutine QP_report(energies,widths)
     !
     use stderr,   ONLY:intc
     !
     logical :: energies,widths
     !
     integer          ::ik,ib
     real(SP)         ::xx_dummy,xc_dummy,r_numbers(20),dscp
     character(schlen)::r_fmt,fmt_,ch1,ch2,ch_spin
     character(4)     ::ch_xx
     character(5)     ::ch_vxc
     !
     if (trim(QP_solver)/='g') then
       !
       ik=QP_table(1,3)
       !
       call section('=','Q(uasi)P(article) properties')
       call msg(' r','Legend (energies in eV):')
       call msg(' r','- B  : Band       - Eo  : bare energy')
       if (energies) then
         call msg(' r','- E  : QP energy  - Z   : Renormalization factor')
         call msg(' r','- So : Sc(Eo)     - S   : Sc(E)')
         if (l_ph_corr) then
           call msg('rn','- Gm : Width [meV]- Gf  : Width [fs]')
         else
           call msg('rn','- xx/Vxc : Sx/Vxc - dSp : Sc derivative precision')
         endif
         call msg('nr','QP [eV] @ K ['//trim(intc(ik))//'] (iku):',k%pt(ik,:))
       else if (widths) then
         call msg(' r','- Z  : Renormalization factor')
         call msg('rn','- Gm : Width [meV] - Gf  : Width [fs]')
         call msg('nr','Lifetimes @ K ['//trim(intc(ik))//'] (iku):',k%pt(ik,:))
       endif
       !
       do i1=1,QP_n_states
         !
         if (l_el_corr.and.energies) then
           xx_dummy=real(QP_Sx(i1))*HARTREE
           xc_dummy=real(QP_Vxc(i1))*HARTREE
         else
           xx_dummy=0.
           xc_dummy=0.
         endif
         !
         ib=QP_table(i1,1)
         if (QP_table(i1,3)/=ik) then
           ik=QP_table(i1,3)
           if (energies) call msg('nr','QP [eV] @ K ['//trim(intc(ik))//'] (iku):',k%pt(ik,:))
           if (widths)   call msg('nr','Lifetimes [eV] @ K ['//trim(intc(ik))//'] (iku):',k%pt(ik,:))
         endif
         !
         if (energies) then
           r_numbers(:7)=(/qp%E_bare(i1)*HARTREE,real(qp%E(i1))*HARTREE,&
&                      real(qp%E(i1)-qp%E_bare(i1))*HARTREE,real(qp%Z(i1)),&
&                      real(QP_Sc(i1,1))*HARTREE,xx_dummy,xc_dummy/)
           if (l_ph_corr) then
             r_numbers(6)=aimag(qp%E(i1))*HARTREE/1.E-3
             r_numbers(7)=0.
             if (r_numbers(6)>0.) r_numbers(7)=0.65822/2./aimag(qp%E(i1))/HARTREE
           endif
           r_fmt=gen_fmt(r_v=r_numbers(:7))
           fmt_='(3(a,f6.2),a,f4.2,4(a,'//trim(r_fmt)//'))'
           !
           !
         endif
         !
         ch_spin=' '
         !
         if (n_sp_pol==2.and.spin(QP_table(i1,:))==1) ch_spin='[up]'
         if (n_sp_pol==2.and.spin(QP_table(i1,:))==2) ch_spin='[dn]'
         !
         if (energies) then
           !
           ch_xx =' xx='
           ch_vxc=' Vxc='
           if (l_ph_corr) ch_xx =' Gm='
           if (l_ph_corr) ch_vxc=' Gf='
           !
           ch1=trim(ch_spin)//' B='//trim(intc(ib))//' Eo='
           write (ch2,trim(fmt_)) trim(ch1),r_numbers(1),&
&            ' E=',r_numbers(2),' E-Eo=',r_numbers(3),' Z=',r_numbers(4),&
&            ' So=',r_numbers(5),ch_xx,r_numbers(6),ch_vxc,r_numbers(7)
           !
           ch1=ch2
           !
           if (QP_dSc_steps>2) then
             dscp=abs(QP_dSc(i1,2)-QP_dSc(i1,1))/abs(QP_dSc(i1,1))
             write (ch2,'(a,i3.3,a)') trim(ch1)//' dSp=',100-int(dscp*100.),'%'
             ch1=trim(ch2)
           endif
           !
           !
         endif
         !
         if (i1/=QP_n_states) call msg('r',trim(ch1))
         if (i1==QP_n_states) call msg('rn',trim(ch1))
         !
       enddo
       !
       ! QP i/o
       !
       if (energies) then
         call io_control(ACTION=OP_WR_CL,COM=REP,SEC=(/1,2,3/),ID=ID)
         io_err=ioQP('QP',qp,ID)
       endif
       !
     endif
     !
     ! o.qp
     !
     if (l_ph_corr)   QP_rep_string=trim(QP_rep_string)//'lm'
     if (widths)      QP_rep_string='kpbne0lmlf'
     if (n_sp_pol==2) QP_rep_string=trim(QP_rep_string)//'sp'
     call QP_of(k,qp,en)
     !
     ! CLEAN
     !
     deallocate(qp%Z,qp%E,qp%E_bare,qp%k,qp%table,QP_table,QP_state)
     if (allocated(QP_Sc))  deallocate(QP_Sc)
     if (allocated(QP_dSc)) deallocate(QP_dSc)
     if (allocated(QP_G))   deallocate(QP_G)
     if (allocated(QP_Sx))  deallocate(QP_Sx,QP_Vxc)
     call mem_est("QP_Sc QP_dSc QP_G QP_Sx QP_Vxc")
     call mem_est("qp_Z qp_E qp_E_bare qp_K qp_table QP_table QP_state")
     !
   end subroutine
   !
end subroutine