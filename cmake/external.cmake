

set(BOOST_COMPONENTS system filesystem)
set(LLVM_COMPONENTS mcjit jit interpreter nativecodegen bitreader asmparser irreader selectiondag native linker ipo)

find_package(Boost COMPONENTS ${BOOST_COMPONENTS})
if (Boost_FOUND)
  message("Found Boost ${Boost_INCLUDE_DIR}")
endif()

# A convenience variable:
set(LLVM_ROOT "" CACHE PATH "Root of LLVM install.")

# A bit of a sanity check:
if( NOT EXISTS ${LLVM_ROOT}/include/llvm )
message(FATAL_ERROR "LLVM_ROOT (${LLVM_ROOT}) is not a valid LLVM install")
endif()

# We incorporate the CMake features provided by LLVM:
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${LLVM_ROOT}/share/llvm/cmake")
include(LLVMConfig)
llvm_map_components_to_libraries(LLVM_LIBRARIES ${LLVM_COMPONENTS})

#OIIO

set(OIIO_ROOT "/usr/local" CACHE PATH "Top-level of the the OIIO install")
set(OIIO_INCLUDE_DIR "${OIIO_ROOT}/include")
set(OIIO_LIBRARY_DIRS "${OIIO_ROOT}/lib")
set(OIIO_LIBRARIES "OpenImageIO")