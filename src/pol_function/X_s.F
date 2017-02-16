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
subroutine X_s(iq,fr,X,wv)
 !
 use pars,          ONLY:SP,pi
 use drivers,       ONLY:l_bs_fxc,l_alda_fxc,l_lrc_fxc
 use timing,        ONLY:live_timing
 use memory_m,      ONLY:mem_est
 use par_proc_m,    ONLY:pp_redux_wait,pp_indexes,myid,ncpu,pp_indexes_reset
 use R_lattice,     ONLY:bare_qpg,q_norm
 use frequency,     ONLY:w_samp
 use par_indexes_m, ONLY:par_indexes
 use stderr,        ONLY:intc
 use X_m,           ONLY:X_t,X_mat,X_fxc
 use matrix_operate,ONLY:mat_dia_inv,INV,USE_LK,USE_SLK,USE_SVD
 use TDDFT,         ONLY:FXC_n_g_corr,FXC,FXC_n_mem_freqs,&
&                        FXC_LRC_alpha,FXC_SVD_digits,ioBS_Fxc
 use IO_m,          ONLY:io_control,OP_RD_CL,NONE
 !
 implicit none
 type(X_t)    :: X
 type(w_samp) :: wv
 integer      :: iq,fr(2)
 !
 ! Work Space
 !
 type(pp_indexes) ::px
 integer     :: i1,i2,iw,nw_max_par,INV_MODE
 complex(SP), allocatable :: Xom1(:,:),tddftk(:,:),Xo(:,:)
 !
 ! Fxc I/O (for the BS based kernel)
 !
 integer           ::ioFxc_err,ID,FXC_w_ref
 !
 ! Setup 
 !
 call pp_indexes_reset(px)
 allocate(tddftk(X%ng,X%ng),Xo(X%ng,X%ng))
 call mem_est("X_WS",(/2*size(Xo)/))
 !
 ! Xo^-1 matrix (BS Fxc)
 !
 if (l_bs_fxc) then
   allocate(Xom1(FXC_n_g_corr,FXC_n_g_corr))
   call mem_est("Xo_m1",(/size(Xom1)/))
 endif
 !
 ! Max number of frequencies inverted in serial mode (nw_max_par)
 !
 nw_max_par=wv%n(2)-mod(wv%n(2),ncpu)
 call par_indexes(px,(/wv%n(2)/))
 if (nw_max_par<wv%n(2)) px%i1p(nw_max_par+1:)=.true.
 call pp_redux_wait
 px%stps(myid+1)=0
 do iw=1,wv%n(2)
   if (iw<=nw_max_par.and..not.px%i1p(iw)) X_mat(:,:,iw)=(0.,0.)
   if (px%i1p(iw)) px%stps(myid+1)=px%stps(myid+1)+1
 enddo
 !
 call live_timing(&
&   'X @q['//trim(intc(iq))//'] '//trim(intc(fr(1)))//'-'//trim(intc(fr(2))),px%stps(myid+1))
 do iw=1,wv%n(2)
   !
   INV_MODE=USE_LK
   Xo=X_mat(:,:,iw)
   tddftk=(0.,0.) 
   !
   ! If the freqs remaining are not anough for all the cpu's or
   ! Fxc needs the SVD procedure use the SLK
   !
   if (iw>nw_max_par.or.FXC_SVD_digits>0) INV_MODE=USE_SLK
   !
   ! TDDFT Kernel. Differente procedure depending on the kernel 
   !  kind: BS,ALDA,LRC.
   !
   if (l_bs_fxc) then
     !
     !
   else if (l_lrc_fxc) then
     !
     ! LRC Fxc
     !
     tddftk(1,1)=-Xo(1,1)*FXC_LRC_alpha/q_norm(iq)**2
     !
   else if (l_alda_fxc) then
     !
     ! ALDA Fxc
     !
     if (.not.px%i1p(iw)) cycle
     tddftk(:,:FXC_n_g_corr)=-matmul(Xo(:,:FXC_n_g_corr),FXC(:,:,1))
     !
   endif
   !
   ! I must cycle here to allow the FXC I/O properly
   !
   if (.not.px%i1p(iw)) cycle
   !
   do i1=1,X%ng ! no Fxc [delta_(g1,g2)-Xo(g1,g2)*v(g2)]
     tddftk(:,i1)=tddftk(:,i1)-Xo(:,i1)*4.*pi/bare_qpg(iq,i1)**2
     tddftk(i1,i1)=tddftk(i1,i1)+1.
   enddo
   call mat_dia_inv(INV,INV_MODE,tddftk)
   !
   ! X(g,gp)=Sum_gpp[tddftk]^-1_(g,gpp)*Xo(gpp,gp)
   !
   X_mat(:,:,iw)=matmul(tddftk,Xo)
   forall(i1=1:X%ng,i2=1:X%ng) &
&     X_mat(i1,i2,iw)=X_mat(i1,i2,iw)*4.*pi/bare_qpg(iq,i1)/bare_qpg(iq,i2)
   call live_timing(steps=1)
   !
 enddo
 !
 call live_timing
 !
 do i1=1,nw_max_par
   call pp_redux_wait(X_mat(:,:,i1))
 enddo
 !
 ! CLEAN
 !
 call pp_indexes_reset(px)
 deallocate(tddftk,Xo)
 if (l_bs_fxc) then
   deallocate(Xom1)
   call mem_est("Xo_m1")
 endif
 call mem_est("X_WS")
 !
end subroutine