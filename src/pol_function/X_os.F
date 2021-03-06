!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM,DS,AF,FA
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
!> @callgraph
!> @callergraph
subroutine X_os(Xo,iq,Xen,Xk,Xw,X)
 !
 ! Non interacting Xo
 !
 ! OPENMP parallelism  (AF & FA)
 !   The current implementation is based on mutexes (locks).
 !   At the price of some replicated memory (Xo_res) it provides a much
 !   better omp scaling.
 !
 !   _NESTING introduces the nesting of scatterbamp parallel regions inside the
 !   outer region opened here (not working yet)
 !
 ! X terminator (BG kind) implemented (IM,AF)
 !
 ! 
 use drivers,       ONLY:l_life
 use IO_m,          ONLY:io_RESPONSE
 use pars,          ONLY:SP,cZERO,schlen
 use wrapper,       ONLY:V_by_V_plus_V
 use LIVE_t,        ONLY:live_timing
 use com,           ONLY:msg,warning,error
 use stderr,        ONLY:intc
 use wave_func,     ONLY:WF
 use parallel_m,    ONLY:PP_redux_wait,PAR_COM_DIPOLES,myid
 use openmp,        ONLY:OPENMP_update,n_threads_X,master_thread,OPENMP_set_threads,n_threads_X,&
&                        n_threads_DIP,n_outthr,n_innthr,OPENMP_locks_reset,n_threads_FFT
#if defined _OPENMP
 use openmp,        ONLY:OPENMP_compute_mutex,omp_locks
#endif
 use frequency,     ONLY:w_samp,bare_grid_N,coarse_grid_N,coarse_grid_Pt
 use interfaces,    ONLY:WF_load
 use D_lattice,     ONLY:i_space_inv
 use electrons,     ONLY:levels
 use R_lattice,     ONLY:qindx_X,bz_samp,G_m_G
 use memory_m,      ONLY:mem_est
 use collision,     ONLY:elemental_collision,elemental_collision_free,elemental_collision_alloc
 use X_m,           ONLY:X_t,X_poles,X_Ein_poles,current_iq,X_poles_tab,&
&                        self_detect_E_range,half_X_mat_only,use_X_DbGd,&
&                        l_X_terminator,X_terminator_E,X_term_E
#if defined _TIMING
 use timing_m,      ONLY:timing
#endif
 implicit none
 type(levels)         :: Xen
 type(bz_samp)        :: Xk
 type(X_t)            :: X
 type(w_samp)         :: Xw
 integer              :: iq
 complex(SP)          :: Xo(X%ng,X%ng,Xw%n_freqs)
 !
 ! Work Space
 !
 character(schlen)        :: live_t_string
 integer                  :: ig1,ig2,iw,n_poles,i_cg,i_bg
 integer                  :: mutexid,ngrho
 logical                  :: force_bare_X_G,Drude_pole,skip_WF_load
 real(SP)                 :: minmax_ehe(2,PAR_COM_DIPOLES%n_CPU),cutoff
 complex(SP)              :: GreenF(Xw%n_freqs),drude_GreenF(Xw%n_freqs)
 complex(SP),allocatable  :: Xo_res(:,:)
 integer,    external     :: X_eh_setup
 type(elemental_collision):: Xo_scatt

 !
 ! Defaults & Setups
 !===================
 Xo             = cZERO
 GreenF         = cZERO
 drude_GreenF   = cZERO
 !
 ! Logicals to use bare or Double Grid GF (no poles accumulation)
 !=======================================================
 force_bare_X_G=use_X_DbGd.or.associated(Xen%W).or.associated(Xen%GreenF)
 !
 skip_WF_load= (iq==1.and.X%ng==1)
 !
 !  Optical strengths
 !=====================
 if (iq==1) then
   !
   call OPENMP_set_threads(n_threads_in=n_threads_DIP)
   !
   call DIPOLE_driver(Xen, Xk, X, X%q0)
   call X_Drude(iq,Xen,Xk,Xw,X%Wd,drude_GreenF)
   !
   call OPENMP_set_threads(n_threads_in=n_threads_X)
   !
 endif
 !
 ! WF load
 !=========
 ngrho=X%ng
 if (l_X_terminator) ngrho=maxval(G_m_G)
 !
 if(.not.skip_WF_load) call WF_load(WF,ngrho,maxval(qindx_X(:,:,2)),X%ib,(/1,Xk%nibz/),title='-X')
 !
#if defined _TIMING
 call timing('Xo (procedure)',OPR='start')
#endif
 !
 ! Poles tabulation
 !==================
 ! 
 if(l_X_terminator) then
   cutoff=minval(Xen%E(X%ib(2),:,:))
   X_term_E=cutoff+X_terminator_E
 endif
 !
 if (iq/=current_iq) then
   !
   n_poles=X_eh_setup(-iq,X,Xen,Xk,minmax_ehe)
   !
   if (n_poles==0) call warning(' [CPU '//trim(intc(myid))//'] has no poles')
   !
   allocate(X_poles_tab(n_poles,4)) 
   call mem_est("X_poles_tab",(/size(X_poles_tab)/))
   !
   if (.not.force_bare_X_G) call FREQUENCIES_coarse_grid('X',X_poles,n_poles,X%cg_percentual,X_Ein_poles,l_X_terminator)
   if (     force_bare_X_G) call FREQUENCIES_coarse_grid('X',X_poles,n_poles,0._SP,0.0_SP,.FALSE.)
   !
   minmax_ehe=0._SP
   !
   n_poles=X_eh_setup(iq,X,Xen,Xk,minmax_ehe(:,PAR_COM_DIPOLES%CPU_id+1))
   deallocate(X_poles,X_Ein_poles)
   !
   if (self_detect_E_range) then
     call PP_redux_wait(minmax_ehe,COMM=PAR_COM_DIPOLES%COMM)
     Xw%er(1)=minval(minmax_ehe(1,:))
     Xw%er(2)=maxval(minmax_ehe(2,:))
   endif
   !
   ! This call is needed as Xw%p is deallocated inside
   ! the q-loop of X_em1. But only when the EM1D is written or when it is not but we are not doing
   ! lifetimes calculations
   !
   if (io_RESPONSE.or.(.not.io_RESPONSE.and..not.l_life)) call FREQUENCIES_setup(Xw)
   !
 endif 
 !
 !
 ! Time-Rev is Spatial Inv => only half X is eval
 !                            ===================
 call WF_spatial_inversion(Xen,Xk)
 !
 half_X_mat_only=i_space_inv==1
 if (.not.half_X_mat_only) half_X_mat_only= all( aimag(Xw%p(:))<1.E-4 ).and. all( real(Xw%p(:))<1.E-4 )
 if (half_X_mat_only.and.current_iq==0) call msg('s','[X] Upper matrix triangle filled')
 !
 ! omp settings and workspace
 !=================================
 !
#if defined _OPENMP
#  if defined _NESTING
 call OPENMP_set_threads(n_threads_in=n_threads_X, use_nested=.true.)
 n_threads_FFT=n_innthr
 call msg('s','[X] NESTED openmp parallelism on: n_outthr/n_innthr = ',(/n_outthr,n_innthr/))
#  else
 call OPENMP_set_threads(n_threads_in=n_threads_X, use_nested=.false.)
 n_threads_FFT=1
 !call msg('s','[X] NESTED openmp parallelism off')
#  endif
#endif
 call OPENMP_locks_reset(INIT=.true.,nlocks=16)
 !
 ! Timing
 !========
 live_t_string='Xo@q['//trim(intc(iq))//'] '
 !
 !
 if(coarse_grid_N>0) call live_timing(trim(live_t_string),coarse_grid_N/n_outthr)
 !
 ! OpenMP setup
 !==============
 !
#if defined _OPENMP
!$omp parallel num_threads(n_outthr) default(shared), &
!$omp &        private(i_cg, Drude_pole,GreenF, i_bg, Xo_res, Xo_scatt, ig2, iw, mutexid)
#endif
 !
 call OPENMP_update(master_thread)
 !
 ! memory estimate and local alloc
 !=================================
 call mem_est("Xo_WS",(/X%ng**2 * n_outthr/))
 allocate(Xo_res(X%ng,X%ng))
 call elemental_collision_free(Xo_scatt,INIT_ONLY=.true.)
 call elemental_collision_alloc(Xo_scatt,NG=ngrho,TITLE="Xo")
 !
 ! MAIN LOOP
 !===========
 !
#if defined _OPENMP
!$omp do
#endif
 do i_cg = 1,coarse_grid_N
   !
   i_bg=sum(bare_grid_N(1:i_cg-1))+1
   !
   ! 1) First compute the residuals
   !================================
   call X_os_residuals(Xen,Xk,X,i_cg,iq,Xo_res,Xo_scatt)
   !
   ! 2) Then the frequency dependent term
   !=======================================
   Drude_pole= (iq==1) .and. abs(coarse_grid_Pt(i_cg))<1.E-5
   !
   if(Drude_pole) then
#if defined _OPENMP
     !$omp critical
#endif
     Xo(1,1,:)=Xo(1,1,:)+Xo_res(1,1)*drude_GreenF(:)/real(bare_grid_N(i_cg))
#if defined _OPENMP
     !$omp end critical
#endif
     call live_timing(steps=1)
     cycle
   endif
   !
   !
   call X_GreenF_analytical(iq,X_poles_tab(i_bg,:),Xw,Xen,Xk,GreenF,X%ordering,'G',.FALSE.)
   !
   !
   ! 3) Finally multiply residual and frequency dependent term
   !===========================================================
   do iw=1,Xw%n_freqs
     !
     do ig2=1,X%ng
#if defined _OPENMP
       call OPENMP_compute_mutex(ig2,mutexid)
       call omp_set_lock(omp_locks(mutexid))
#endif
       call V_by_V_plus_V(ig2,GreenF(iw),Xo_res(:ig2,ig2),Xo(:ig2,ig2,iw))
       !
       if (.not.half_X_mat_only) then
         call V_by_V_plus_V(X%ng-ig2,GreenF(iw),conjg(Xo_res(ig2,ig2+1:)),Xo(ig2+1:,ig2,iw))
       endif
#if defined _OPENMP
       call omp_unset_lock(omp_locks(mutexid))
#endif
     enddo
     !
   enddo
   !
   if (master_thread) call live_timing(steps=1)
   !
 enddo 
#if defined _OPENMP
!$omp end do
#endif
 !
 ! CLEAN
 !=======
 call mem_est("Xo_WS")
 deallocate(Xo_res)
 call elemental_collision_free(Xo_scatt)
 !
#if defined _OPENMP
!$omp end parallel
#endif
 !
 !
 if(coarse_grid_N>0) call live_timing()
 !
 call OPENMP_update(master_thread) 
 call OPENMP_locks_reset()
 !
#if defined _TIMING
 call timing('Xo (procedure)',OPR='stop')
 call timing('Xo (REDUX)',OPR='start')
#endif
 !
 do iw=1,Xw%n_freqs
   call PP_redux_wait(Xo(:,:,iw),COMM=PAR_COM_DIPOLES%COMM)
 enddo
 !
#if defined _TIMING
 call timing('Xo (REDUX)',OPR='stop')
#endif
 !
 ! Symmetrize Xo when only half has been avaluated
 !=================================================
 !
 if (half_X_mat_only) then
   !
#if defined _OPENMP
   !$omp parallel default(shared), private(ig2,ig1)
#endif
   if (i_space_inv==0) then
#if defined _OPENMP
     !$omp do
#endif
     do ig2=1,X%ng
       do ig1=ig2+1,X%ng
         Xo(ig1,ig2,:)=conjg(Xo(ig2,ig1,:))
       enddo
     enddo
#if defined _OPENMP
     !$omp end do
#endif
   endif
   !
   if (i_space_inv==1) then
#if defined _OPENMP
     !$omp do
#endif
     do ig2=1,X%ng
       do ig1=ig2+1,X%ng
         Xo(ig1,ig2,:)=Xo(ig2,ig1,:)
       enddo
     enddo
#if defined _OPENMP
     !$omp end do
#endif
   endif
#if defined _OPENMP
   !$omp end parallel
#endif
   !
 endif
 !
 current_iq=iq
 n_threads_FFT=0
 !
end subroutine
