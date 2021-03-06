!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): DS AM
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
subroutine K_IP(iq,Ken,Xk,X_oscillators,W_bss)
 !
 use pars,          ONLY:SP,IP,pi,cZERO,cI
 use units,         ONLY:HA2EV
 use frequency,     ONLY:w_samp
 use LIVE_t,        ONLY:live_timing
 use drivers,       ONLY:l_rpa_IP,l_bs_fxc
 use com,           ONLY:msg
 use R_lattice,     ONLY:bz_samp,d3k_factor,q_norm
 use electrons,     ONLY:levels,spin_occ,spin,E_SOC_nbands,nel,n_sp_pol
 use interfaces,    ONLY:PARALLEL_WF_distribute
 use X_m,           ONLY:X_t,Epsilon_ii,Joint_DOS,alpha_dim,eps_2_alpha,&
&                        DIP_projected,X_drude_term,X_alloc,iw_ref,global_gauge,   &
&                        skip_cond_sum_rule,l_drude,Dipole_Energy_treshold
 use BS_solvers,    ONLY:BSS_Vnl_included,BSS_add_antiresonant,BSS_eval_JDOS,&
&                        BSS_n_freqs,BSS_q0,Co_factor,BSS_Wd
 use BS,            ONLY:BS_T_grp,BS_K_coupling,BS_nT_grps
 use parallel_m,    ONLY:PAR_BS_nT_col_grps,PP_redux_wait,PAR_COM_eh_INDEX,PAR_IND_T_groups,&
&                        PAR_IND_Xk_ibz,PAR_IND_CON_BANDS_X,PAR_IND_VAL_BANDS_X,&
&                        PAR_Xk_bz_index,PAR_COM_Xk_ibz_INDEX
#if defined _KERR
 use drivers,       ONLY:l_kerr
 use X_m,           ONLY:Epsilon_ij
 use KERR,          ONLY:A_drude
#endif
#if defined _TIMING
 use timing_m,       ONLY:timing
#endif
 !
 implicit none
 type(levels) ::Ken
 type(bz_samp)::Xk
 type(X_t)    ::X_oscillators
 type(w_samp) ::W_bss
 integer      ::iq
 !
 ! Work space
 !
 integer           ::ik_bz,iv,ic,i_sp_pol,i_T_g,i_T,ik_bz_mem,n_SOC,i_pert_SOC
 real(SP)          ::conjg_fac,Z_
 complex(SP)       ::drude_GreenF(W_bss%n_freqs),res,E_plus_W0,E_plus_W(2/n_sp_pol),diam_term,diam_term0
 !
 call section('=','Independent Particles absorption') 
 !===================================================
 !
#if defined _TIMING
 call timing('T_space IP',OPR='start')
#endif
 !
 ! Look for the W(iw_ref) closest 0
 !==================================
 call FREQUENCIES_set_reference_point(W_bss%p,BSS_n_freqs)
 !
 if (l_bs_fxc) goto 1
 !
 ! Polarizability ?
 !==================
 if (trim(alpha_dim)/='adim') then
   call msg('r', 'Optical renormalization   [au]:',eps_2_alpha)
   call msg('rn','Polarizability dimension      :',trim(alpha_dim))
 endif
 !
 ! Eps_0
 !=======
 allocate(Epsilon_ii(BSS_n_freqs,4)) ! 2 (int) 3 (non int) 4 (n-1 Haydock/inv shifted)
 allocate(X_drude_term(BSS_n_freqs))
 Epsilon_ii   = cZERO
 X_drude_term = cZERO
 !
 Epsilon_ii(:,1)=W_bss%p(:)  
 if (BSS_eval_JDOS) then
   allocate(Joint_DOS(BSS_n_freqs,4))
   Joint_DOS=cZERO
   Joint_DOS(:,1) =W_bss%p(:)
 endif
 !
 !
 !...Drude
 call X_Drude(1,Ken,Xk,W_bss,BSS_Wd,drude_GreenF)
 if (l_drude) drude_GreenF=drude_GreenF*(Ken%f(Ken%bf,Ken%kf,Ken%sf)*(spin_occ-Ken%f(Ken%bf,Ken%kf,Ken%sf)))
 !
 ! WF distribution
 !=================
 call PARALLEL_WF_distribute(K_index=PAR_IND_Xk_ibz,&
&                            B_index=PAR_IND_CON_BANDS_X(X_oscillators%whoami),&
&                            Bp_index=PAR_IND_VAL_BANDS_X(X_oscillators%whoami),&
&                            CLEAN_UP=.TRUE.)
 !
 ! Oscillators I/O & Eps0
 !========================
 !
 if (iq==1) then
   !
   if( E_SOC_nbands==0.or.n_sp_pol==2) then
     n_SOC=1
     Co_factor=real(spin_occ)/(2._SP*pi)**3*d3k_factor*4._SP*pi
   endif
   !
   !
#if defined _KERR
   if (trim(global_gauge)=='velocity') A_drude(1)=cZERO
#endif
   !
   call DIPOLE_driver(Ken,Xk,X_oscillators,BSS_q0)
   !
   BSS_Vnl_included=X_oscillators%Vnl_included
   !
   if (trim(global_gauge)=='length'  ) conjg_fac=-1._SP
   if (trim(global_gauge)=='velocity') conjg_fac=+1._SP
   !
   if (l_rpa_IP) call live_timing('IP absorption',PAR_BS_nT_col_grps)
   !
   do i_T_g=1,BS_nT_grps
     !
     if (.not.PAR_IND_T_groups%element_1D(i_T_g)) cycle
     !
     do i_T=1,BS_T_grp(i_T_g)%size
       !
       ik_bz = BS_T_grp(i_T_g)%table(i_T,1)
       iv    = BS_T_grp(i_T_g)%table(i_T,2)
       ic    = BS_T_grp(i_T_g)%table(i_T,3)
       i_sp_pol = BS_T_grp(i_T_g)%table(i_T,4)
       !
       ik_bz_mem= PAR_Xk_bz_index(ik_bz)
       !
       if(.not.allocated(BS_T_grp(i_T_g)%W)) E_plus_W0=BS_T_grp(i_T_g)%E(i_T)
       if(     allocated(BS_T_grp(i_T_g)%W)) E_plus_W0=BS_T_grp(i_T_g)%E(i_T)-cI*BS_T_grp(i_T_g)%W(i_T)
       !
       if (E_SOC_nbands==0) E_plus_W=E_plus_W0
       !
       !
       ! *length*   : DIP_projected(c,v,k) is    iq*<v|r|c> while I need    iq*<c|r|v> = -conjg(   iq*<v|r|c>)
       ! *velocity* : DIP_projected(c,v,k) is q_ver*<v|p|c> while I need q_ver*<c|r|v> =  conjg(q_ver*<v|r|c>)
       !              see definition of conjg_fac few lines before for the -1
       !
       BS_T_grp(i_T_g)%dipoles_R(i_T)=conjg_fac*conjg(DIP_projected(ic,iv,ik_bz_mem,i_sp_pol))
       if (BS_K_coupling) BS_T_grp(i_T_g)%dipoles_A(i_T)=DIP_projected(ic,iv,ik_bz_mem,i_sp_pol)
       !
       if ( abs(real(E_plus_W0)) < Dipole_Energy_treshold ) cycle
       !
       ! Residuals DIP_cv * DIP_vc
       !
       Z_=1._SP
       if (allocated(BS_T_grp(i_T_g)%Z)) Z_=BS_T_grp(i_T_g)%Z(i_T)
       !
       res=BS_T_grp(i_T_g)%dipoles_R(i_T)*conjg(BS_T_grp(i_T_g)%dipoles_R(i_T))*BS_T_grp(i_T_g)%f_RES(i_T)*Z_
       if (allocated(BS_T_grp(i_T_g)%W) .and. trim(global_gauge)=="velocity") res=res*E_plus_W0/conjg(E_plus_W0)
       !
       !
       do i_pert_SOC=1,n_SOC
         !
         Epsilon_ii(:,3)=Epsilon_ii(:,3)-res/(W_bss%p(:)-E_plus_W(i_pert_SOC))
         if (BSS_eval_JDOS) Joint_DOS(:,3) =Joint_DOS(:,3) -1._SP/(W_bss%p(:)-E_plus_W(i_pert_SOC))
         if (BSS_add_antiresonant.or.BS_K_coupling) then
           Epsilon_ii(:,3)=Epsilon_ii(:,3)+conjg(res)/(W_bss%p(:)+conjg(E_plus_W(i_pert_SOC)))
           if (BSS_eval_JDOS) Joint_DOS(:,3) =Joint_DOS(:,3) +    1._SP/(W_bss%p(:)+conjg(E_plus_W(i_pert_SOC)))
         endif
         !
         !
       enddo
       !
     enddo
     !
     if (l_rpa_IP) call live_timing(steps=1)
     !
   enddo
   !
   if (l_rpa_IP) call live_timing()
   !
   ! ALL 2 ALL
   !
   call PP_redux_wait( Epsilon_ii(:,3) ,COMM=PAR_COM_Xk_ibz_INDEX%COMM )
   call PP_redux_wait( Epsilon_ii(:,3) ,COMM=PAR_COM_eh_INDEX%COMM )
   if (BSS_eval_JDOS) call PP_redux_wait( Joint_DOS(:,3)  ,COMM=PAR_COM_Xk_ibz_INDEX%COMM )
   if (BSS_eval_JDOS) call PP_redux_wait( Joint_DOS(:,3)  ,COMM=PAR_COM_eh_INDEX%COMM )
#if defined _KERR
   call PP_redux_wait( A_drude(1) ,COMM=PAR_COM_Xk_ibz_INDEX%COMM )
   call PP_redux_wait( A_drude(1) ,COMM=PAR_COM_eh_INDEX%COMM )
#endif
   !
   ! DOS
   !=====
   if (BSS_eval_JDOS) Joint_DOS(:,3)=Joint_DOS(:,3)*Co_factor
   !
   ! Pure diamagnetic term
   !=======================
   diam_term0=cmplx(nel*real(Xk%nbz,SP)/spin_occ,0._SP,SP)
   !
   if (trim(global_gauge)=='length'  ) then
     !
     Epsilon_ii(:,3)=1._SP+Epsilon_ii(:,3)*Co_factor/q_norm(1)**2
     !
   else if (trim(global_gauge)=='velocity') then
     !
     if (.not.skip_cond_sum_rule) then
       ! Here I impose the conductivity sum rule for the velocity gauge
       call msg('nsr','Gauge velocity: reference freq. for w=0 is [eV]:',real(W_bss%p(iw_ref))*HA2EV )
       diam_term=Epsilon_ii(iw_ref,3)
     else
       diam_term=diam_term0
     endif
     !
     Epsilon_ii(:,3)=1._SP+(Epsilon_ii(:,3)-diam_term)*Co_factor/W_bss%p(:)**2
     !
   endif
   !
   ! Drude
   !=======
   !
   if (l_drude.and..not.skip_cond_sum_rule) then
     X_drude_term(:)=-drude_GreenF(:)
     Epsilon_ii(:,3)=Epsilon_ii(:,3)+X_drude_term(:)*Co_factor/q_norm(1)**2
   endif
   !
   !
#if defined _KERR
   if (l_kerr) call K_kerr_IP(iq,W_bss%p)
#endif
   !
 endif
 !
 ! CLEAN
 !
 if (iq==1) call X_alloc('DIP_projected')
 !
 if (l_rpa_IP) then
   !
   ! Initialize & write the output file
   !
   call K_output_file(iq,"open IP")
   call K_output_file(iq,"IP")
   !
   deallocate(Epsilon_ii,X_drude_term)
   if (BSS_eval_JDOS) deallocate(Joint_DOS)
#if defined _KERR
   if(l_kerr) deallocate(Epsilon_ij)
#endif
   !
 endif
 !
1 continue
 !
#if defined _TIMING
 call timing('T_space IP',OPR='stop')
#endif
 !
   !
   !
end subroutine
