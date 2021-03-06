! 
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): CA, DS, AM
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
subroutine electrons_bands(Xk,Xen,BANDS_range)
 !
 use pars,           ONLY:SP,schlen
 use units,          ONLY:HA2EV
 use YPP,            ONLY:BANDS_steps,coo_in,coo_out,k_transform,interp_grid
 use electrons,      ONLY:levels,n_sp_pol,n_spinor
 use R_lattice,      ONLY:bz_samp,bz_samp_reset
 use com,            ONLY:msg,of_open_close,error,warning
 use vec_operate,    ONLY:c2a,v_norm,iku_v_norm
 use parser_m,       ONLY:parser
 use stderr,         ONLY:intc
 use interpolate,    ONLY:reset_interpolation,electrons_bands_interpolate
 use QP_CTL_m,       ONLY:QP_apply
 !
 implicit none
 !
 type(bz_samp), intent(inout) :: Xk
 type(levels),  intent(in)    :: Xen
 integer,       intent(inout) :: BANDS_range(2)
 !
 type(bz_samp)         :: USER_K,CIRCUIT_K,INTERP_K
 real(SP), pointer     :: bands_interpolated(:,:,:)
 real(SP), allocatable :: spin_interpolated(:,:,:),magn_interpolated(:,:,:)
 !
 integer               :: is,ik,ikbz,ib,nbands,ID_interp
 real(SP)              :: tmp_k(3)
 real(SP), allocatable :: values(:),spin_values(:,:),magn_values(:,:),circuit_versor(:,:)
 character(8)          :: spin_ch
 character(schlen)     :: file_name_bands(2,n_sp_pol),file_name_grid(n_sp_pol)
 character(schlen), allocatable :: headings(:)
 !
 call section('*','Interpolation tool')
 !=====================================
 !
 ! Apply QP corrections
 !====================== 
 call QP_apply(BANDS_range,Xen,Xk,'G',msg_fmt='s')
 !
 ! IBZ => BZ: need to be done here as QP_apply cleans the %ptbz allocation
 !
 call k_ibz2bz(Xk,'iku',.TRUE.)
 !
 ! Perform the energies interpolation
 !====================================
 call electrons_bands_interpolate(Xen,Xk,ID_interp,USER_k,INTERP_k,CIRCUIT_k,BANDS_range,bands_interpolated)
 !
 ! Perform interpolation of spinorial factors and magnetization
 !==============================================================
 if(n_spinor>1 .and. BANDS_steps> 0) then
   allocate(spin_interpolated(BANDS_range(1):BANDS_range(2),CIRCUIT_k%nibz,n_spinor))
   allocate(magn_interpolated(BANDS_range(1):BANDS_range(2),CIRCUIT_k%nibz,3))
   call electrons_spin_and_magn_interpolate(Xen,Xk,CIRCUIT_k,BANDS_range,spin_interpolated,magn_interpolated)
 endif
 !
 call reset_interpolation(ID_interp)
 !
 ! Output
 !========
 ! 1: bands on circuit    if (BANDS_steps>0) ; 
 ! 2: dos on regular grid if (interp_grid>0) ; 
 !
 nbands=BANDS_range(2)-BANDS_range(1)+1
 !
 allocate(values(nbands+4),headings(nbands+4))
 values=0._SP
 if(n_spinor==2) then
   allocate(spin_values(nbands+4,2),magn_values(nbands+4,3))
   spin_values=0._SP
   magn_values=0._SP
 endif
 !
 headings(1)=" |k| "
 do ib=BANDS_range(1),BANDS_range(2)
   headings(1+ib-BANDS_range(1)+1)=' b'//intc(ib)
 enddo
 headings(nbands+2:nbands+4)=(/" kx  "," ky  "," kz  "/)
 !
 file_name_bands= " "
 file_name_grid = " "
 spin_ch        = " "
 !
 do is=1,n_sp_pol
   if (n_sp_pol>1.and.is==1) spin_ch="_spin-up"
   if (n_sp_pol>1.and.is==2) spin_ch="_spin-dn"
   file_name_bands(2,is)="bands_built_in"//trim(spin_ch)
   if(BANDS_steps> 0)     file_name_bands(1,is)="bands_interpolated"//trim(spin_ch)
   if(all(interp_grid>0)) file_name_grid(is)   ="grid"//trim(spin_ch)
   call of_open_close(trim(file_name_grid(is)),'ot')
   call of_open_close(trim(file_name_bands(1,is)),'ot')
   call of_open_close(trim(file_name_bands(2,is)),'ot')
 enddo
 !
 do is=1,n_sp_pol
   call msg('o '//trim(file_name_bands(1,is)),"#",headings,INDENT=0,USE_TABS=.true.)
   call msg('o '//trim(file_name_bands(1,is)),"#")
   call msg('o '//trim(file_name_bands(2,is)),"#",headings,INDENT=0,USE_TABS=.true.)
   call msg('o '//trim(file_name_bands(2,is)),"#")
 enddo
 !
 if(BANDS_steps> 0.and.n_spinor==2) then
   call of_open_close("spin_factors_1",'ot')
   call of_open_close("spin_factors_2",'ot')
   call of_open_close("magnetization_x",'ot')
   call of_open_close("magnetization_y",'ot')
   call of_open_close("magnetization_z",'ot')
   call msg('o spin_factors_1',"#",headings,INDENT=0,USE_TABS=.true.)
   call msg('o spin_factors_1',"#")
   call msg('o spin_factors_2',"#",headings,INDENT=0,USE_TABS=.true.)
   call msg('o spin_factors_2',"#")
   call msg('o magnetization_x',"#",headings,INDENT=0,USE_TABS=.true.)
   call msg('o magnetization_x',"#")
   call msg('o magnetization_y',"#",headings,INDENT=0,USE_TABS=.true.)
   call msg('o magnetization_y',"#")
   call msg('o magnetization_z',"#",headings,INDENT=0,USE_TABS=.true.)
   call msg('o magnetization_z',"#")
 endif
 !
 call msg('o path',"#"," ",INDENT=0)
 !
 coo_out=coo_in
 !
 values(1)=0._SP
 !
 if(BANDS_steps> 0) then
   !
   allocate(circuit_versor(USER_K%nibz-1,3))
   !
   do ik=1,USER_K%nibz-1
     tmp_k=USER_K%pt(ik+1,:)-USER_K%pt(ik,:)
     circuit_versor(ik,:)=tmp_k/v_norm(tmp_k)
   enddo
   !
   do ik=1,USER_K%nibz-1
     !
     if (ik>1) values(1)=values(1)+iku_v_norm(USER_K%pt(ik,:)-USER_K%pt(ik-1,:))
     !
     do ikbz=1,Xk%nbz
       !
       tmp_k=Xk%ptbz(ikbz,:)-USER_K%pt(ik,:)
       !
       if ((abs(v_norm(tmp_k)-dot_product(tmp_k,circuit_versor(ik,:)))<1.E-5).and.&
  &           iku_v_norm(tmp_k)<=iku_v_norm(USER_K%pt(ik+1,:)-USER_K%pt(ik,:))         ) then
         !
         do is=1,n_sp_pol
           values(1+1:nbands+1)=Xen%E(BANDS_range(1):BANDS_range(2),Xk%sstar(ikbz,1),is)*HA2EV
           values(nbands+2:nbands+4)=Xk%ptbz(ikbz,:)
           call k_transform(values(nbands+2:nbands+4),'iku')
           call msg('o '//trim(file_name_bands(2,is)),' ',(/values(1)+iku_v_norm(tmp_k),values(2:)/),INDENT=0,USE_TABS=.true.)
         enddo
         !
         ! DEBUG <
         !write (*,'(10f10.6)') values(1)+iku_v_norm(tmp_k),Xen%E(4,Xk%sstar(ikbz,1),1)*HA2EV,tmp_k
         ! DEBUG >
         !
       endif
       !
     enddo
   enddo
   !
   deallocate(circuit_versor)
   !
   values(1)=0._SP
   !
   do ik=1,CIRCUIT_K%nibz
     !
     if (ik>1) values(1)=values(1)+iku_v_norm(CIRCUIT_K%pt(ik,:)-tmp_k)
     if (ik<CIRCUIT_K%nibz) tmp_k=CIRCUIT_K%pt(ik,:)
     !
     call k_transform(CIRCUIT_K%pt(ik,:),"iku")
     !
     if(n_spinor==2) then
       spin_values(1,:)=values(1)
       magn_values(1,:)=values(1)
     endif
     do is=1,n_sp_pol
       values(1+1:nbands+1)=bands_interpolated(BANDS_range(1):BANDS_range(2),is,ik)*HA2EV
       values(nbands+2:nbands+4)=CIRCUIT_K%pt(ik,:)
       call msg('o '//trim(file_name_bands(1,is)),' ',values,INDENT=0,USE_TABS=.true.)
       if(n_spinor==2) then
         spin_values(1+1:nbands+1,1)=spin_interpolated(BANDS_range(1):BANDS_range(2),ik,1)
         spin_values(1+1:nbands+1,2)=spin_interpolated(BANDS_range(1):BANDS_range(2),ik,2)
         spin_values(nbands+2:nbands+4,1)=CIRCUIT_K%pt(ik,:)
         spin_values(nbands+2:nbands+4,2)=CIRCUIT_K%pt(ik,:)
         call msg('o spin_factors_1',' ',spin_values(:,1),INDENT=0,USE_TABS=.true.)
         call msg('o spin_factors_2',' ',spin_values(:,2),INDENT=0,USE_TABS=.true.)
         magn_values(1+1:nbands+1,1)=magn_interpolated(BANDS_range(1):BANDS_range(2),ik,1)
         magn_values(1+1:nbands+1,2)=magn_interpolated(BANDS_range(1):BANDS_range(2),ik,2)
         magn_values(1+1:nbands+1,3)=magn_interpolated(BANDS_range(1):BANDS_range(2),ik,3)
         magn_values(nbands+2:nbands+4,1)=CIRCUIT_K%pt(ik,:)
         magn_values(nbands+2:nbands+4,2)=CIRCUIT_K%pt(ik,:)
         magn_values(nbands+2:nbands+4,3)=CIRCUIT_K%pt(ik,:)
         call msg('o magnetization_x',' ',magn_values(:,1),INDENT=0,USE_TABS=.true.)
         call msg('o magnetization_y',' ',magn_values(:,2),INDENT=0,USE_TABS=.true.)
         call msg('o magnetization_z',' ',magn_values(:,3),INDENT=0,USE_TABS=.true.)
       endif
     enddo
     !
   enddo
   !
 endif
 !
 if(all(interp_grid>0)) then
   !
   headings(1)  =  " ik  "
   headings(2:4)=(/" kx  "," ky  "," kz  "/)
   do ib=BANDS_range(1),BANDS_range(2)
     headings(4+ib-BANDS_range(1)+1)=' b'//intc(ib)
   enddo
   !
   do is=1,n_sp_pol
     call msg('o '//trim(file_name_grid(is)),"#",headings,INDENT=0,USE_TABS=.true.)
   enddo
   !
   do ikbz=1,INTERP_K%nbz
     call k_transform(INTERP_K%ptbz(ikbz,:),"iku")
     values(2:4)=INTERP_K%ptbz(ikbz,:)
     !
     ik=INTERP_K%sstar(ikbz,1)
     !
     values(1)=real(ik,SP)
     !
     do is=1,n_sp_pol
       values(1+4:nbands+4)=bands_interpolated(BANDS_range(1):BANDS_range(2),is,ik)*HA2EV
       call msg('o '//trim(file_name_grid(is)),' ',values,INDENT=0,USE_TABS=.true.)
     enddo
     !
   enddo
   !
 endif
 !
 deallocate(values,headings)
 if(n_spinor==2) deallocate(spin_values,magn_values)
 !
 deallocate(bands_interpolated)
 nullify(bands_interpolated)
 if(n_spinor==2) deallocate(spin_interpolated,magn_interpolated)
 !
 do is=1,n_sp_pol
   call of_open_close(trim(file_name_bands(1,is)))
   call of_open_close(trim(file_name_bands(2,is)))
   call of_open_close(trim(file_name_grid(is)))
 enddo
 !
 if(BANDS_steps> 0.and.n_spinor==2) call of_open_close("spin_factors")
 !
end subroutine
