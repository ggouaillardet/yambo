!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM,DS,AF
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
subroutine scatter_Bamp(isc)
 !
 ! rhotw(G)=<ib ik_is i_sp| e^[I(RsG-G0).r] | ob ok_os o_sp>   
 !
 !  is(3)=(ib,ik,is,i_sp) --<--:--<-- os(3)=(ob,ok,os,o_sp)
 !                             :
 !                            /:\ iqs=(ig0,iq,qs)
 !                             :
 !
 !                     \:/
 ! REMEMBER that     ->-:->-  =  conjg [-<-:-<-]
 !                                        /:\
 !  iq_is = ik_is-ok_os-Go
 !
 use pars,           ONLY:cZERO,cONE,DP,SP
 use electrons,      ONLY:n_spinor
 use collision,      ONLY:elemental_collision
 use D_lattice,      ONLY:idt_index
 use R_lattice,      ONLY:g_rot
 use FFT_m,          ONLY:fft_size,fft_dim,fft_g_table
#if defined _FFTW
 use FFT_m,          ONLY:fftw_plan
#endif
 !
 implicit none
 !
 type(elemental_collision)::isc
 !
 integer     :: qs,iGo
#if defined _FFTQE && !defined _USE_3D_FFT || defined _OPENMP
 integer     :: ig, ir
#endif
 !
 ! |ib ik_is i_sp>
 call WF_apply_symm(isc%is,isc%WF_symm_i)
 !
 ! | ob ok_os o_sp>   
 call WF_apply_symm(isc%os,isc%WF_symm_o)
 !
 ! \tilde{\rho} in Real Space
 !
#if defined _FFTQE && !defined _USE_3D_FFT
 ! 
 ! add one extra conjg since FFTQE cannot account for the conjg in one go
 ! 
 !$omp parallel default(shared), private(ir)
 !$omp do
 do ir = 1, fft_size
   isc%rho_tw_rs(ir) = cmplx(isc%WF_symm_i(ir,1)*conjg(isc%WF_symm_o(ir,1)),kind=DP)
 enddo
 !$omp end do
 !
 if (n_spinor==2) then
 !$omp do
   do ir = 1, fft_size
     isc%rho_tw_rs(ir) = isc%rho_tw_rs(ir)+cmplx(isc%WF_symm_i(ir,2)*conjg(isc%WF_symm_o(ir,2)),kind=DP)
   enddo
 !$omp end do
 endif
 !$omp end parallel
 !
#else
!
#if defined _OPENMP
 !$omp parallel default(shared), private(ir)
 !$omp do
 do ir = 1, fft_size
   isc%rho_tw_rs(ir) = cmplx(conjg(isc%WF_symm_i(ir,1))*isc%WF_symm_o(ir,1),kind=DP)
 enddo
 !$omp end do
 !
 if (n_spinor==2) then
 !$omp do
   do ir = 1, fft_size
     isc%rho_tw_rs(ir) = isc%rho_tw_rs(ir)+cmplx(conjg(isc%WF_symm_i(ir,2))*isc%WF_symm_o(ir,2),kind=DP)
   enddo
 !$omp end do
 endif
 !$omp end parallel
#else
 isc%rho_tw_rs(:)=cmplx(conjg(isc%WF_symm_i(:,1))*isc%WF_symm_o(:,1),kind=DP)
 if (n_spinor==2) isc%rho_tw_rs(:)=isc%rho_tw_rs(:)+cmplx(conjg(isc%WF_symm_i(:,2))*isc%WF_symm_o(:,2),kind=DP)
#endif
 !
#endif
 !
 ! perform the actual FFT
 !
#if defined _FFTW
 call fft_3d(isc%rho_tw_rs,fft_dim,+1,fftw_plan)
#elif defined _FFTSG || (defined _USE_3D_FFT && defined _FFTQE)
 call fft_3d(isc%rho_tw_rs,fft_dim,+1)
#elif defined _FFTQE
 !
 ! the QE fft must be performed in the right
 ! direction. conjg is taken care separately
 ! AF: please note the different definition of isc%rho_tw_rs above
 !     (one extra conjg has been added)
 !
 call fft_3d(isc%rho_tw_rs,fft_dim,-1)
 !
#else
#error "[CPP] Inconsistent FFT environment"
#endif
 !
 ! e^[I(Rs(G-G0)).r]
 !
 iGo=isc%qs(1)
 qs =isc%qs(3)
 !
#if defined _FFTQE && !defined _USE_3D_FFT
 !
 ! one extra conjg is performed on rho_tw_rs
 if (qs==idt_index) then 
   !$omp parallel do default(shared), private(ig)
   do ig = 1, isc%ngrho
     isc%rhotw(ig)= cmplx(conjg(isc%rho_tw_rs(fft_g_table(ig,iGo))),kind=SP)
   enddo
   !$omp end parallel do
 else
   !$omp parallel do default(shared), private(ig)
   do ig = 1, isc%ngrho
     isc%rhotw(ig)= cmplx(conjg(isc%rho_tw_rs(fft_g_table(g_rot(qs,ig),iGo))),kind=SP)
   enddo
   !$omp end parallel do
 endif
#else
#  if defined _OPENMP
 if (qs==idt_index) then 
   !$omp parallel do default(shared), private(ig)
   do ig = 1, isc%ngrho
     isc%rhotw(ig)= cmplx(isc%rho_tw_rs(fft_g_table(ig,iGo)),kind=SP)
   enddo
   !$omp end parallel do
 else
   !$omp parallel do default(shared), private(ig)
   do ig = 1, isc%ngrho
     isc%rhotw(ig)= cmplx(isc%rho_tw_rs(fft_g_table(g_rot(qs,ig),iGo)),kind=SP)
   enddo
   !$omp end parallel do
 endif
#  else
 if (qs==idt_index) isc%rhotw(1:isc%ngrho)= cmplx(isc%rho_tw_rs(fft_g_table(1:isc%ngrho,iGo)),kind=SP)
 if (qs/=idt_index) isc%rhotw(1:isc%ngrho)= cmplx(isc%rho_tw_rs(fft_g_table(g_rot(qs,1:isc%ngrho),iGo)),kind=SP)
#  endif
#endif
 !
 ! q=0, G=0 case
 !
 if (all((/isc%qs(2)==1,isc%is(1)==isc%os(1)/))) isc%rhotw(1)=cONE
 if (all((/isc%qs(2)==1,isc%is(1)/=isc%os(1)/))) isc%rhotw(1)=cZERO
 !
end subroutine
