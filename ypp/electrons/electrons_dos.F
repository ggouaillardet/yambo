! 
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM, DS
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
subroutine electrons_dos(Xk,Xen)
 !
 use units,          ONLY:HA2EV
 use pars,           ONLY:SP,schlen
 use R_lattice,      ONLY:bz_samp
 use electrons,      ONLY:levels,spin,n_spinor,n_spin,BZ_DbGd_nbands
 use YPP,            ONLY:output_fname,dos_broadening,dos_bands,&
&                         dos_E_range,dos_E_steps
 use com,            ONLY:msg,of_open_close
 use QP_CTL_m,       ONLY:QP_apply
 use LIVE_t,         ONLY:live_timing
 use interfaces,     ONLY:PARALLEL_index,el_density_of_states
 use parallel_m,     ONLY:PP_indexes,myid,PP_redux_wait,PP_indexes_reset
 !
 implicit none
 !
 type(bz_samp) ::Xk
 type(levels)  ::Xen
 !
 ! Work Space
 ! 
 real(SP)              :: el_dos(dos_E_steps,n_spin),dos_E,delta_E,el_dos_max
 real(SP),allocatable  :: WF_fac(:,:,:)
 integer               :: i_E
 character(schlen)     :: titles(4)
 logical               :: l_DbGd,l_separate_eh
 type(PP_indexes)      :: px
 !
 call section('*','Electronic DOS')
 !
 ! E Double Grid
 !===============
 !
 l_DbGd=.FALSE.
 if (BZ_DbGd_nbands>0) then
   l_DbGd=.TRUE.
   call OCCUPATIONS_Extend(Xen,Xen)
 endif
 !
 if (n_spinor==2) then
   allocate(WF_fac(dos_bands(1):dos_bands(2),Xk%nibz,2))
   call electrons_spin_factors(Xk,(/1,Xk%nibz/),dos_bands,WF_fac)
 endif
 !
 if (l_DbGd) dos_bands(2)=min(dos_bands(2),BZ_DbGd_nbands)
 !
 el_dos_max=0._SP
 !
 call QP_state_table_setup(Xen)
 call QP_apply(dos_bands,Xen,Xk,'G',msg_fmt='s')
 !
 ! Output files headers
 !
 output_fname='el_dos'
 call of_open_close(trim(output_fname),'ot')
 if (n_spin==1) then
   titles(1)='E[eV]'
   titles(2)='DOS'
   call msg('o dos','#',titles(:2),INDENT=0,USE_TABS=.true.)    
 else
   titles(1)='E[eV]'
   titles(2)='DOS [up]'
   titles(3)='DOS [dn]'
   titles(4)='DOS [up+dn]'
   call msg('o dos','#',titles(:4),INDENT=0,USE_TABS=.true.)    
 endif
 call msg('o dos',"#")
 !
 if (dos_E_range(1)>dos_E_range(2)) then
   dos_E_range(1)=minval(Xen%E(dos_bands(1):dos_bands(2),:,:))-5._SP*dos_broadening
   dos_E_range(2)=maxval(Xen%E(dos_bands(1):dos_bands(2),:,:))+5._SP*dos_broadening
 endif
 delta_E=(dos_E_range(2)-dos_E_range(1))/dos_E_steps
 !
 ! Parallel setup and live_timing
 !================================
 !
 call PP_indexes_reset(px)
 call PARALLEL_index(px,(/dos_E_steps/))
 call live_timing('DOS',px%n_of_elements(myid+1))
 !
 el_dos(:,:)=0._SP
 !
 do i_E=1,dos_E_steps
   !
   if (.not.px%element_1D(i_E)) cycle
   !
   dos_E=dos_E_range(1)+i_E*delta_E
   !
   if(.not.allocated(WF_fac)) call el_density_of_states(Xk,Xen,dos_E,dos_broadening,dos_bands,el_dos(i_E,:),l_DbGd)
   if(     allocated(WF_fac)) call el_density_of_states(Xk,Xen,dos_E,dos_broadening,dos_bands,el_dos(i_E,:),l_DbGd,WF_fac=WF_fac)
   !
   call live_timing(steps=1)
   !
 enddo
 !
 call PP_redux_wait(el_dos)
 !
 if (n_spinor==2) deallocate(WF_fac)
 !
 el_dos_max=max(el_dos_max,maxval(abs(el_dos)))
 !
 ! Output file
 !
 l_separate_eh=.true.
 !
 do i_E=1,dos_E_steps
   dos_E=dos_E_range(1)+i_E*delta_E
   !
   if (n_spin==1) call msg('o dos','',(/dos_E*HA2EV,el_dos(i_E,1)/),INDENT=-2,USE_TABS=.true.)
   if (n_spin==2) call msg('o dos','',(/dos_E*HA2EV,el_dos(i_E,:),  &
&                                           el_dos(i_E,1)+el_dos(i_E,2)/),INDENT=-2,USE_TABS=.true.)
 enddo
 !
 call live_timing(steps=1)
 !
 !
 call of_open_close(trim(output_fname))
 !
 call live_timing()
 !
end subroutine
